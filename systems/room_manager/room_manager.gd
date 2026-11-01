class_name RoomManager
extends Node
## Загружает комнату в нужной реальности, применяет правила отражения,
## переносит героя через зеркала и возрождает его у осколка (§12.2).
## Комната каждый раз пересоздаётся, но мир помнит своё (GameState): открытые сундуки — навсегда,
## убитые враги и разбитые скаты — до отдыха у осколка или смерти героя (переход через зеркало
## их не возвращает), панели с сундуком — навсегда, отзвук героя — на месте гибели.

const NORMAL: StringName = &"normal"
## Сколько секунд после смерти до затемнения.
const DEATH_HOLD := 1.9
## Музыка комнаты — пока вместо тона комнаты (тихий фон зала ещё не выбран). Играет без перерыва:
## смерть и переход через зеркало пересоздают комнату, а не менеджер.
const MUSIC_PATH := "res://audio/music/room_music.ogg"
const MUSIC_VOLUME_DB := -14.0

@export var room_scene: PackedScene
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
var reality: StringName = NORMAL

## Правила, с которыми строится каждая реальность (запоминаются, чтобы возрождаться в отражении).
var _reality_rules: Dictionary = {NORMAL: []}
var _busy := false
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
	level_menu = LevelMenu.new()
	hud.add_child(level_menu)
	level_menu.closed.connect(_on_level_menu_closed)
	player.died.connect(_on_player_died)
	_load_room(GameState.checkpoint_reality)
	player.respawn(_checkpoint_position())
	camera_rig.snap_to_target()
	hud.fade_to(0.0, 0.6)
	_start_music()
	if hide_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


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


func _load_room(target_reality: StringName) -> void:
	if current_room:
		remove_child(current_room)
		current_room.queue_free()
	var room := room_scene.instantiate() as Room
	room.apply_reality(target_reality)
	for rule: MirrorTransformation in _reality_rules.get(target_reality, []):
		rule.apply(room)
	for path: NodePath in GameState.killed_in(target_reality):
		var dead := room.get_node_or_null(path)
		if dead:
			dead.free()
	add_child(room)
	current_room = room
	for path: NodePath in GameState.broken_glass_in(target_reality):
		var glass := room.get_node_or_null(path) as GlassSurface
		if glass:
			glass.set_broken()
	reality = target_reality
	_apply_mood()
	var shard := current_room.get_node_or_null(GameState.checkpoint_path) as MirrorShard
	if shard and GameState.checkpoint_reality == reality:
		shard.set_lit(true)
	Events.reality_changed.emit(reality)
	# После возрождения героя: силуэт строится из его облика, а не из позы смерти.
	_spawn_hero_echo.call_deferred()


func _apply_mood() -> void:
	var mirrored := reality != NORMAL
	world_environment.environment = mirror_environment if mirrored else normal_environment
	sun.light_color = mirror_sun_color if mirrored else normal_sun_color


func _on_mirror_used(portal: MirrorPortal) -> void:
	if _busy:
		return
	_busy = true
	var portal_path := current_room.get_path_to(portal)
	var target := portal.destination_reality if reality != portal.destination_reality else NORMAL
	if target != NORMAL:
		_reality_rules[target] = portal.transformations
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
	GameState.set_checkpoint(reality, current_room.get_path_to(shard))
	for other in get_tree().get_nodes_in_group("mirror_shard"):
		if other != shard:
			other.set_lit(false)
	await _rest()
	open_level_menu()


## Меню у осколка: отзвуки — в прожитые годы. Комната уже новая, берём новый осколок.
func open_level_menu() -> void:
	_busy = true
	var shard := current_room.get_node_or_null(GameState.checkpoint_path) as Node3D
	level_menu.open(player, shard if shard else current_room)


func _on_level_menu_closed() -> void:
	_busy = false
	if hide_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Отдых у осколка — как у костра в Souls: каждое касание пересоздаёт комнату (враги снова
## на местах), герой встаёт у осколка с полным здоровьем и выносливостью.
func _rest() -> void:
	if _busy:
		return
	_busy = true
	player.frozen = true
	await hud.fade_to(1.0, 0.3)
	GameState.restore_world()
	_load_room(reality)
	player.respawn(_checkpoint_position())
	camera_rig.snap_to_target()
	player.frozen = false
	await hud.fade_to(0.0, 0.4)
	_busy = false


func _on_player_died() -> void:
	_busy = true
	GameState.drop_echoes(reality, player.last_ground, player.death_weapon, player.facing)
	# Дать телу упасть и прочитать надпись.
	await get_tree().create_timer(DEATH_HOLD).timeout
	await hud.fade_to(1.0, 0.5)
	GameState.restore_world()
	_load_room(GameState.checkpoint_reality)
	player.respawn(_checkpoint_position())
	camera_rig.snap_to_target()
	hud.hide_death()
	await hud.fade_to(0.0, 0.5)
	_busy = false


## Враг погиб: мир его запоминает, а отзвук летит к герою.
func _on_enemy_killed(enemy: Dummy) -> void:
	GameState.mark_killed(reality, current_room.get_path_to(enemy))
	if enemy.echoes > 0:
		EchoDrop.spawn(current_room, enemy.global_position + Vector3(0.0, 0.8, 0.0), enemy.echoes, player)


func _on_glass_broken(glass: GlassSurface) -> void:
	var memory := glass.memory()
	if memory != GlassSurface.Memory.NONE and current_room.is_ancestor_of(glass):
		GameState.mark_glass(reality, current_room.get_path_to(glass), memory == GlassSurface.Memory.FOREVER)


func _spawn_hero_echo() -> void:
	var echo := GameState.hero_echo
	if echo.is_empty() or echo["reality"] != reality or not is_instance_valid(current_room):
		return
	HeroEcho.spawn(current_room, echo["position"], player, echo["weapon"], echo["facing"])


func _checkpoint_position() -> Vector3:
	var node := current_room.get_node_or_null(GameState.checkpoint_path) as Node3D
	if node == null:
		node = current_room.get_node(^"Spawns/PlayerStart") as Node3D
	if node.has_method("get_spawn_position"):
		return node.get_spawn_position()
	return node.global_position
