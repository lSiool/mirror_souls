class_name RoomManager
extends Node
## Загружает комнату в нужной реальности, применяет правила отражения,
## переносит героя через зеркала и возрождает его у осколка (§12.2).
## Комната каждый раз пересоздаётся, но мир помнит своё (GameState): открытые сундуки — навсегда,
## убитые враги и разбитые скаты — до отдыха у осколка или смерти героя (переход через зеркало
## их не возвращает), панели с сундуком — навсегда, отзвук героя — на месте гибели.
## Комнат много: двери ведут из одной в другую, а память мира у каждой комнаты своя.
## Мир пишется на диск при переходах, отдыхе, находках и выходе из игры.

const NORMAL: StringName = &"normal"
const ROOM_PATH := "res://world/rooms/%s.tscn"
## Сколько секунд после смерти до затемнения.
const DEATH_HOLD := 1.9
## С какой скоростью герой вылетает из стеклянной преграды в новую комнату (вперёд, вверх).
const BURST_SPEED := Vector2(9.0, 4.0)
## У осколка герой стоит сбоку, на таком расстоянии (м), и держит ладонь на кристалле.
const SHARD_TOUCH_GAP := 0.45
## Гибель на уровне-забеге (§8.11): сколько темно, как долго проявляется картинка и сколько
## герой сидит у осколка, прежде чем сможет встать.
const RUN_WAKE_DARK := 1.0
const RUN_WAKE_FADE := 2.4
const RUN_WAKE_SIT := 0.8
## Любое из этих действий поднимает очнувшегося героя.
const WAKE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"jump", &"roll", &"attack", &"interact"]
## Музыка комнаты — пока вместо тона комнаты (тихий фон зала ещё не выбран). Играет без перерыва:
## смерть и переход через зеркало пересоздают комнату, а не менеджер.
const MUSIC_PATH := "res://audio/music/room_music.ogg"
const MUSIC_VOLUME_DB := -14.0
const VIGNETTE := """
shader_type canvas_item;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.46)) * vec2(1.0, 1.15);
	COLOR = vec4(0.0, 0.0, 0.02, smoothstep(0.34, 0.8, length(d)) * 0.86);
}
"""

## Хаб: главный осколок у часовни — к нему переносятся с любого другого осколка.
const HUB_ROOM: StringName = &"chapel_yard"
const HUB_SHARD: NodePath = ^"Objects/MirrorShard"

## С какой комнаты начинается новая игра.
@export var start_room: StringName = &"village_hut"
@export var player_path: NodePath
@export var camera_rig_path: NodePath
@export var hud_path: NodePath
@export var world_environment_path: NodePath
@export var sun_path: NodePath

@export_group("Реальности")
@export var normal_environment: Environment
@export var mirror_environment: Environment
@export var normal_sun_color := Color(1.0, 0.88, 0.72)
@export var mirror_sun_color := Color(0.62, 0.78, 1.0)
## Указатель мыши в игре не виден: куда целится герой, показывает сам лук.
@export var hide_cursor := true

var current_room: Room
var current_room_id: StringName
var reality: StringName = NORMAL

var _busy := false
var _sun_energy := 1.1
var music: AudioStreamPlayer
var level_menu: LevelMenu

@onready var player: Player = get_node(player_path)
@onready var camera_rig: CameraRig = get_node(camera_rig_path)
@onready var hud: Hud = get_node(hud_path)
@onready var world_environment: WorldEnvironment = get_node(world_environment_path)
@onready var sun: DirectionalLight3D = get_node(sun_path)


func _ready() -> void:
	Events.mirror_used.connect(_on_mirror_used)
	Events.checkpoint_activated.connect(_on_checkpoint_activated)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.glass_broken.connect(_on_glass_broken)
	Events.door_used.connect(_on_door_used)
	Events.item_found.connect(func(_id: StringName) -> void: save_now())
	level_menu = LevelMenu.new()
	hud.add_child(level_menu)
	level_menu.closed.connect(_on_level_menu_closed)
	level_menu.title_requested.connect(return_to_title)
	Settings.apply()
	level_menu.hub_requested.connect(travel_to_hub)
	level_menu.return_requested.connect(travel_back)
	player.died.connect(_on_player_died)
	_sun_energy = sun.light_energy
	_setup_picture()
	_start_music()
	# Пока комнаты нет, герой висит на месте: иначе, пока открыто меню, он падает в пустоту и гибнет.
	player.frozen = true
	if GameState.saves_enabled and GameState.has_save():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var menu := StartMenu.new()
		hud.add_child(menu)
		var resume: bool = await menu.chosen
		menu.queue_free()
		if not resume:
			# После выхода в главное меню в памяти ещё прошлая игра.
			GameState.reset()
		_begin(resume)
	else:
		_begin(false)


## Слои картинки по образцу Mandragora: плоскость боя в фокусе, дальний план и тёмный передний
## размыты глубиной, края кадра притемнены, взгляд идёт в светлую середину (GAME_DESIGN §2.2).
func _setup_picture() -> void:
	var focus := CameraAttributesPractical.new()
	focus.dof_blur_far_enabled = true
	focus.dof_blur_far_distance = 24.0
	focus.dof_blur_far_transition = 14.0
	focus.dof_blur_near_enabled = true
	focus.dof_blur_near_distance = 10.0
	focus.dof_blur_near_transition = 4.0
	focus.dof_blur_amount = 0.07
	world_environment.camera_attributes = focus
	var shader := Shader.new()
	shader.code = VIGNETTE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var veil := ColorRect.new()
	veil.material = mat
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(veil)
	hud.move_child(veil, 0)


## Начать игру: новую — со стартовой комнаты, или с места из сохранения.
func _begin(resume: bool) -> void:
	var extra := GameState.load_game() if resume else {}
	# Сохранение из старой версии, где комнаты уже нет, — начать заново, а не упасть.
	if not extra.is_empty() and not ResourceLoader.exists(ROOM_PATH % extra["room"]):
		extra = {}
	if not ResourceLoader.exists(ROOM_PATH % GameState.checkpoint_room):
		GameState.checkpoint_room = start_room
		GameState.checkpoint_path = ^"Spawns/PlayerStart"
	if extra.is_empty():
		GameState.checkpoint_room = start_room
		player.equip(GameState.weapon_id)
		_load_room(NORMAL, start_room)
		player.respawn(_checkpoint_position())
	else:
		player.stats.from_dict(extra["stats"])
		player.equip(GameState.weapon_id)
		_load_room(extra["reality"], extra["room"])
		player.respawn(extra["position"])
	player.frozen = false
	camera_rig.snap_to_target()
	hud.fade_to(0.0, 0.6)
	if hide_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Записать мир и где стоит герой. Мёртвый не сохраняется: смерть сохранится после возрождения.
func save_now() -> void:
	if current_room == null or player.is_dead():
		return
	# На уровне-забеге игра не пишется (§8.11): продолжение — с места перед входом.
	if RunLevel.of(current_room):
		return
	GameState.save_game({"room": current_room_id, "reality": reality, "position": player.safe_ground,
		"stats": player.stats.to_dict()})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream := load(MUSIC_PATH) as AudioStreamOggVorbis
	stream.loop = true
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = MUSIC_VOLUME_DB
	add_child(music)
	music.play()


## Память мира: у каждой комнаты в каждой реальности своя.
func _world_key(room_id: StringName, in_reality: StringName) -> StringName:
	return StringName("%s/%s" % [room_id, in_reality])


func _load_room(target_reality: StringName, room_id: StringName = current_room_id) -> void:
	if current_room:
		remove_child(current_room)
		current_room.queue_free()
	var room := (load(ROOM_PATH % room_id) as PackedScene).instantiate() as Room
	var key := _world_key(room_id, target_reality)
	var rules := _rules_for(room, target_reality)
	room.apply_reality(target_reality)
	room.apply_fire_state()
	for rule: MirrorTransformation in rules:
		rule.apply(room)
	for path: NodePath in GameState.killed_in(key):
		var dead := room.get_node_or_null(path)
		if dead:
			dead.free()
	add_child(room)
	current_room = room
	current_room_id = room_id
	for path: NodePath in GameState.broken_glass_in(key):
		var glass := room.get_node_or_null(path) as GlassSurface
		if glass:
			glass.set_broken()
	reality = target_reality
	_apply_mood()
	var shard := current_room.get_node_or_null(GameState.checkpoint_path) as MirrorShard
	if shard and GameState.checkpoint_reality == reality and GameState.checkpoint_room == room_id:
		shard.set_lit(true)
	Events.reality_changed.emit(reality)
	# После возрождения героя: силуэт строится из его облика, а не из позы смерти.
	_spawn_hero_echo.call_deferred()


## Правила отражения этой реальности: их хранит зеркало комнаты, которое в неё ведёт.
func _rules_for(room: Room, target_reality: StringName) -> Array[MirrorTransformation]:
	var rules: Array[MirrorTransformation] = []
	if target_reality != NORMAL:
		for node in room.layout_objects():
			if node is MirrorPortal and node.destination_reality == target_reality:
				rules.assign(node.transformations)
	return rules


func _apply_mood() -> void:
	var mirrored := reality != NORMAL
	if not mirrored and current_room.is_burning():
		world_environment.environment = current_room.burning_mood
		sun.light_color = current_room.burning_sun_color
		sun.light_energy = current_room.burning_sun_energy
		return
	if not mirrored and current_room.mood:
		world_environment.environment = current_room.mood
		sun.light_color = current_room.sun_color
		sun.light_energy = current_room.sun_energy
		return
	world_environment.environment = mirror_environment if mirrored else normal_environment
	sun.light_color = mirror_sun_color if mirrored else normal_sun_color
	sun.light_energy = _sun_energy


func _on_door_used(door: RoomDoor) -> void:
	await travel(door.target_room, door.target_spawn, door.glass_gate)


## Перейти в другую комнату: герой встаёт в заданной точке, лицом к её середине.
## burst — переход сквозь стеклянную преграду: герой вылетает в комнату вместе с осколками.
func travel(room_id: StringName, spawn: NodePath, burst := false) -> void:
	if _busy:
		return
	_busy = true
	player.frozen = true
	player.velocity = Vector3.ZERO
	await hud.fade_to(1.0, 0.25)
	# Вышел с уровня-забега — он пройден, второй раз туда не попасть (§8.11).
	var run := RunLevel.of(current_room)
	if run:
		run.close()
	_load_room(NORMAL, room_id)
	var marker := current_room.get_node(spawn) as Node3D
	player.teleport(marker.global_position)
	player.facing = 1.0 if marker.global_position.x < current_room.center_x else -1.0
	camera_rig.snap_to_target()
	player.frozen = false
	if burst:
		_burst_in(marker.global_position)
	save_now()
	await hud.fade_to(0.0, 0.3)
	_busy = false


## Вылет из стеклянной преграды (§8.11): осколки, звон, герой летит вперёд.
func _burst_in(at: Vector3) -> void:
	player.velocity = Vector3(player.facing * BURST_SPEED.x, BURST_SPEED.y, 0.0)
	Sfx.play(&"glass_break", at + Vector3(0.0, 1.2, 0.0))
	HitSpark.spawn(current_room, at + Vector3(0.0, 1.3, 0.3), RoomDoor.GATE_TINT, 44)
	Events.camera_shake_requested.emit(0.3, 0.2)


## Герой приходит в себя после сцены: мир уже другой (флаг), комната пересоздана, он лежит и встаёт.
## Точка пробуждения становится точкой возрождения. Сцену ведёт менеджер: её узел уйдёт вместе с комнатой.
func wake_up(flag: StringName, spawn: NodePath, text: String) -> void:
	_busy = true
	await hud.fade_to(1.0, 1.2)
	# Сцена кончилась: камера и кадр как обычно.
	hud.cinematic(false, 0.0)
	camera_rig.zoom(1.0, 0.0)
	GameState.set_flag(flag)
	GameState.set_checkpoint(current_room_id, NORMAL, spawn)
	_load_room(NORMAL, current_room_id)
	player.respawn((current_room.get_node(spawn) as Node3D).global_position)
	player.knock_down()
	camera_rig.snap_to_target()
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 1.8)
	await get_tree().create_timer(0.8).timeout
	player.stand_up()
	Events.message.emit(text)
	save_now()
	_busy = false


func _on_mirror_used(portal: MirrorPortal) -> void:
	if _busy:
		return
	_busy = true
	var portal_path := current_room.get_path_to(portal)
	var target := portal.destination_reality if reality != portal.destination_reality else NORMAL
	player.frozen = true
	await hud.fade_to(1.0, 0.25)
	_load_room(target)
	var exit_portal := current_room.get_node_or_null(portal_path) as MirrorPortal
	var at := exit_portal.get_entry_position() if exit_portal else _checkpoint_position()
	player.teleport(at)
	player.facing = -player.facing
	camera_rig.snap_to_target()
	player.frozen = false
	await hud.fade_to(0.0, 0.35)
	_busy = false


func _on_checkpoint_activated(shard: MirrorShard) -> void:
	if _busy:
		return
	GameState.set_checkpoint(current_room_id, reality, current_room.get_path_to(shard))
	# Главное Зеркало считает активированные на пути осколки.
	GameState.set_flag(StringName("shard_%s" % current_room_id))
	for other in get_tree().get_nodes_in_group("mirror_shard"):
		if other != shard:
			other.set_lit(false)
	# Встаёт с той стороны, откуда подошёл, лицом к осколку.
	var side := signf(shard.global_position.x - player.global_position.x)
	await _rest(side if side != 0.0 else player.facing)
	open_level_menu()


## Меню у осколка: отзвуки — в прожитые годы. Комната уже новая, берём новый осколок.
func open_level_menu() -> void:
	_busy = true
	var shard := current_room.get_node_or_null(GameState.checkpoint_path) as Node3D
	level_menu.hub_available = can_travel_to_hub()
	level_menu.return_place = LevelMenu.place_name(GameState.hub_return["room"]) if can_travel_back() else ""
	# Пока открыто меню, ладонь героя лежит на кристалле.
	if shard is MirrorShard:
		player.touching = (shard as MirrorShard).crystal
	level_menu.open(player, shard if shard else current_room)


## С любого осколка, кроме главного, можно перенестись к главному — у часовни, где хаб.
## Главный осколок должен быть уже зажжён.
func can_travel_to_hub() -> bool:
	return GameState.has_flag(StringName("shard_%s" % HUB_ROOM)) \
		and not (current_room_id == HUB_ROOM and reality == NORMAL)


## Перенос к главному осколку — как отдых у него: мир восстановлен, возрождение теперь там.
## Осколок, от которого ушли, запоминается: от главного к нему можно вернуться (§8.4).
func travel_to_hub() -> void:
	if _busy or not can_travel_to_hub():
		return
	GameState.hub_return = {"room": current_room_id, "reality": reality, "path": GameState.checkpoint_path}
	await _travel_to_shard(HUB_ROOM, NORMAL, HUB_SHARD)


## От главного осколка можно вернуться к тому, с которого герой сюда перенёсся.
func can_travel_back() -> bool:
	return current_room_id == HUB_ROOM and reality == NORMAL and not GameState.hub_return.is_empty() \
		and ResourceLoader.exists(ROOM_PATH % GameState.hub_return["room"])


## Возврат от главного осколка к прежнему — тоже как отдых у него.
func travel_back() -> void:
	if _busy or not can_travel_back():
		return
	var to: Dictionary = GameState.hub_return
	GameState.hub_return = {}
	await _travel_to_shard(to["room"], to["reality"], to["path"])


func _travel_to_shard(room_id: StringName, in_reality: StringName, shard: NodePath) -> void:
	_busy = true
	player.frozen = true
	player.velocity = Vector3.ZERO
	Sfx.play_ui(&"glass_glint", -6.0)
	await hud.fade_to(1.0, 0.6)
	GameState.set_checkpoint(room_id, in_reality, shard)
	GameState.restore_world()
	_load_room(in_reality, room_id)
	player.respawn(_checkpoint_position(), false)
	camera_rig.snap_to_target()
	player.frozen = false
	save_now()
	await hud.fade_to(0.0, 0.6)
	_busy = false


## Меню паузы (§8.12): мир не останавливается, как в Dark Souls; открыть нельзя в переходе,
## у осколка и мёртвым.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or level_menu.is_open or _busy:
		return
	if player.frozen or player.is_dead() or current_room == null:
		return
	get_viewport().set_input_as_handled()
	level_menu.open_pause(player)


## «Выйти в главное меню»: мир сохранён, игра начинается заново с экрана «Продолжить / Новая игра».
func return_to_title() -> void:
	save_now()
	_busy = true
	player.frozen = true
	await hud.fade_to(1.0, 0.5)
	get_tree().reload_current_scene()


func _on_level_menu_closed() -> void:
	player.touching = null
	_busy = false
	save_now()
	if hide_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Отдых у осколка — как у костра в Souls: каждое касание пересоздаёт комнату (враги снова
## на местах), герой встаёт у осколка с полным здоровьем и выносливостью. Неуязвимого мигания
## нет: отдых — не возрождение. side — с какой стороны осколка встать (0 — на самом осколке).
func _rest(side := 0.0) -> void:
	if _busy:
		return
	_busy = true
	player.frozen = true
	await hud.fade_to(1.0, 0.3)
	GameState.restore_world()
	_load_room(reality)
	player.respawn(_checkpoint_position(), false)
	var shard := current_room.get_node_or_null(GameState.checkpoint_path) as MirrorShard
	if shard and side != 0.0:
		player.teleport(shard.get_spawn_position() + Vector3(-side * SHARD_TOUCH_GAP, 0.0, 0.0))
		player.facing = side
	camera_rig.snap_to_target()
	player.frozen = false
	await hud.fade_to(0.0, 0.4)
	_busy = false


func _on_player_died() -> void:
	if current_room == null:
		return
	# Погиб с открытым меню паузы (мир не стоял) — меню закрывается.
	if level_menu.is_open:
		level_menu.close()
	_busy = true
	var run := RunLevel.of(current_room)
	if run and run.next_room != &"":
		await _wake_after_run(run)
		return
	# Отзвук остаётся на последнем безопасном месте — до ловушки, что убила героя.
	GameState.drop_echoes(_world_key(current_room_id, reality), player.safe_ground, player.death_weapon, player.facing)
	# Дать телу упасть и прочитать надпись.
	await get_tree().create_timer(DEATH_HOLD).timeout
	await hud.fade_to(1.0, 0.5)
	GameState.restore_world()
	_load_room(GameState.checkpoint_reality, GameState.checkpoint_room)
	player.respawn(_checkpoint_position())
	camera_rig.snap_to_target()
	hud.hide_death()
	save_now()
	await hud.fade_to(0.0, 0.5)
	_busy = false


## Гибель на уровне-забеге (§8.11): назад дороги нет. Герой сам появляется у следующего осколка —
## сидит возле него, будто только открыл глаза после падения. Осколок зажжён, отзвук героя ждёт
## перед ним, уровень закрыт. Встаёт по первому действию игрока.
func _wake_after_run(run: RunLevel) -> void:
	var next_room := run.next_room
	var shard_path := run.next_shard
	var echo_path := run.echo_spawn
	var wake_path := run.wake_spawn
	var weapon := player.death_weapon
	await get_tree().create_timer(DEATH_HOLD).timeout
	await hud.fade_to(1.0, 0.5)
	run.close()
	GameState.set_checkpoint(next_room, NORMAL, shard_path)
	GameState.set_flag(StringName("shard_%s" % next_room))
	GameState.restore_world()
	_load_room(NORMAL, next_room)
	var echo_at := current_room.get_node_or_null(echo_path) as Node3D
	var at := echo_at.global_position if echo_at else _checkpoint_position()
	GameState.drop_echoes(_world_key(next_room, NORMAL), at, weapon, -1.0)
	var wake_at := current_room.get_node_or_null(wake_path) as Node3D
	player.respawn(wake_at.global_position if wake_at else _checkpoint_position())
	player.facing = -1.0 if at.x < player.global_position.x else 1.0
	player.knock_down(false, true)
	camera_rig.snap_to_target()
	hud.hide_death()
	# Записать сразу: вышел из игры, не встав, — уровень всё равно позади.
	save_now()
	await get_tree().create_timer(RUN_WAKE_DARK).timeout
	await hud.fade_to(0.0, RUN_WAKE_FADE)
	await get_tree().create_timer(RUN_WAKE_SIT).timeout
	while not _wake_pressed():
		await get_tree().physics_frame
	player.stand_up()
	_busy = false


func _wake_pressed() -> bool:
	for action in WAKE_ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false


## Враг погиб: мир его запоминает, а отзвук летит к герою.
func _on_enemy_killed(enemy: Dummy) -> void:
	if not enemy.leaves_statue:
		GameState.mark_killed(_world_key(current_room_id, reality), current_room.get_path_to(enemy))
	# Мастерство: очки оружию героя, треть — оружию врага: побеждая копейщика, учишься копью.
	var xp := enemy.mastery_points()
	GameState.add_mastery(enemy.last_weapon, xp)
	if enemy.weapon_type != enemy.last_weapon:
		GameState.add_mastery(enemy.weapon_type, xp / 3.0)
	if enemy.drop_item != &"" and not (enemy.drop_flag != &"" and GameState.has_flag(enemy.drop_flag)):
		GameState.add_item(enemy.drop_item, enemy.drop_count)
		if enemy.drop_flag != &"":
			GameState.set_flag(enemy.drop_flag)
		Events.item_found.emit(enemy.drop_item)
	if enemy.echoes > 0:
		EchoDrop.spawn(current_room, enemy.global_position + Vector3(0.0, 0.8, 0.0), enemy.echoes, player)


func _on_glass_broken(glass: GlassSurface) -> void:
	var memory := glass.memory()
	if memory != GlassSurface.Memory.NONE and current_room.is_ancestor_of(glass):
		GameState.mark_glass(_world_key(current_room_id, reality), current_room.get_path_to(glass), memory == GlassSurface.Memory.FOREVER)


func _spawn_hero_echo() -> void:
	var echo := GameState.hero_echo
	if echo.is_empty() or echo["reality"] != _world_key(current_room_id, reality) or not is_instance_valid(current_room):
		return
	HeroEcho.spawn(current_room, echo["position"], player, echo["weapon"], echo["facing"])


func _checkpoint_position() -> Vector3:
	var node := current_room.get_node_or_null(GameState.checkpoint_path) as Node3D
	if node == null:
		node = current_room.get_node(^"Spawns/PlayerStart") as Node3D
	if node.has_method("get_spawn_position"):
		return node.get_spawn_position()
	return node.global_position
