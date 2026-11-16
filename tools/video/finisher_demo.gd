extends Node
## Показ добиваний в игре (§6.1): бот сам подходит и добивает — стоящего раненого врага кнопкой
## (знак над ним, волна отбрасывает соседа), сбитого с ног — сверху, вампира — серебряным колом.
## Потом управление у игрока: рядом встаёт ещё один раненый враг — добей сам (U / правый стик).
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/video/finisher_demo.tscn
## Видео: добавить --write-movie out.avi --fixed-fps 30 и аргумент «-- movie» (тогда в конце выход).

const DUMMY := preload("res://actors/enemies/dummy.tscn")
## Где ставить врагов: от солдата комнаты-полигона, вправо.
const FOE_AT := 2.5
const WALK_TO := 1.3

var _main: Node
var _rooms: RoomManager
var _player: Player
var _soldier: Dummy
var _caption: Label
var _movie := false


func _ready() -> void:
	_movie = OS.get_cmdline_user_args().has("movie")
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	await _wait(2.0)
	_rooms = _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	_rooms.hud.popup.blocks_interact = false
	_rooms.hud.popup.queue.clear()
	_rooms.hud.popup.dismiss()
	_soldier = _rooms.current_room.get_node("Objects/Soldier") as Dummy
	_soldier.detect_range = 0.0
	_soldier.patrol_distance = 0.0
	_caption_layer()
	_player.health.taken_mult = 0.0

	# 1. Раненый враг: знак, кнопка — смертельное добивание; сосед отлетает от волны.
	var base := _soldier.global_position.x
	var foe := _spawn(base + FOE_AT)
	_player.teleport(Vector3(base - 2.0, 0.1, 0.0))
	_player.facing = 1.0
	await _say("Враг ранен: следующий удар убьёт — над ним знак добивания", 0.5)
	_wound(foe)
	await _walk_to(foe)
	await _wait(1.2)
	await _say("Кнопка добивания (U) — смертельное добивание. Солдат рядом отлетает от волны", 0.0)
	await _tap(&"finisher")
	await _wait(4.0)

	# 2. Сбитый с ног — добить лежачего, только кнопкой.
	var floored := _spawn(_player.global_position.x + FOE_AT + 1.0)
	await _wait(0.5)
	await _say("Сбитого с ног добивают сверху — тоже кнопкой", 0.3)
	floored._set_state(Dummy.State.KNOCKDOWN)
	floored.floored_by_blow = true
	await _walk_to(floored)
	await _wait(0.8)
	await _tap(&"finisher")
	await _wait(2.5)
	if is_instance_valid(floored):
		floored.queue_free()

	# 3. Вампир — серебряным колом в сердце.
	var vampire := _spawn(_player.global_position.x + FOE_AT + 1.0)
	vampire.creature = CreatureKind.Kind.VAMPIRE
	GameState.add_item(Player.STAKE_ITEM)
	await _wait(0.5)
	await _say("Вампира, пока есть серебряный кол, — колом в сердце (кол тратится)", 0.3)
	_wound(vampire)
	await _walk_to(vampire)
	await _wait(1.0)
	await _tap(&"finisher")
	await _wait(3.5)

	if _movie:
		get_tree().quit()
		return
	# 4. Сам: ещё один раненый враг. Можно добить ударом (J) или кнопкой (U).
	var yours := _spawn(_player.global_position.x + FOE_AT + 1.5)
	await _wait(0.4)
	_wound(yours)
	_player.health.taken_mult = 1.0
	await _say("Твоя очередь: подойди — U добивание, J обычный удар. Esc — пауза", 0.0)


func _spawn(x: float) -> Dummy:
	var foe := DUMMY.instantiate() as Dummy
	foe.position = Vector3(x, 0.0, 0.0)
	foe.detect_range = 0.0
	foe.patrol_distance = 0.0
	_rooms.current_room.get_node("Objects").add_child(foe)
	foe.facing = -1.0
	return foe


## Ранить так, чтобы следующий удар героя убил.
func _wound(foe: Dummy) -> void:
	foe.health.take_damage(foe.health.current - _player._next_hit_damage() * 0.5)


func _walk_to(foe: Dummy) -> void:
	Input.action_press("move_right")
	for i in 600:
		await get_tree().physics_frame
		if foe.global_position.x - _player.global_position.x <= WALK_TO:
			break
	Input.action_release("move_right")


func _tap(action: StringName) -> void:
	Input.action_press(action)
	for i in 3:
		await get_tree().physics_frame
	Input.action_release(action)


func _say(text: String, after: float) -> void:
	_caption.text = text
	await _wait(after)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _caption_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 70.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override(&"font_size", 30)
	_caption.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override(&"outline_size", 8)
	layer.add_child(_caption)
