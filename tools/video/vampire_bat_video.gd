extends Node
## Видео приёма вампира «Мышь» (§6.3) в галерее замка: взлёт, пике, превращение, пролёты мыши.
## Бот за героя: отходит на дистанцию, в пике уходит перекатом, от пролёта мыши — прыжком.
## xvfb-run Godot --path . --write-movie out.avi --fixed-fps 30 res://tools/video/vampire_bat_video.tscn
## Урон по герою ослаблен, чтобы ролик не оборвался смертью.

const LENGTH := 26.0

var _main: Node
var _player: Player
var _rooms: RoomManager
var _vamp: Vampire
var _time := 0.0
var _cooldown := 0.0
var _running := false


func _ready() -> void:
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
	await _rooms.travel(&"castle_gallery", ^"Spawns/PlayerStart")
	await _wait(0.4)
	_rooms.hud.popup.queue.clear()
	_rooms.hud.popup.dismiss()
	_vamp = _rooms.current_room.get_node("Objects/Vampire") as Vampire
	_vamp.bat_first_delay = 0.8
	_vamp.bat_cooldown = 7.0
	_player.teleport(Vector3(_vamp.global_position.x - 6.5, _vamp.global_position.y + 0.1, 0.0))
	_player.facing = 1.0
	_player.health.taken_mult = 0.3
	_running = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	_cooldown -= delta
	if _time > LENGTH or not is_instance_valid(_vamp):
		get_tree().quit()
		return
	for a in ["move_left", "move_right", "attack", "roll", "jump"]:
		Input.action_release(a)
	if _player.health.current < _player.health.max_health * 0.4:
		_player.health.heal_full()
	if _cooldown > 0.0 or _player.state != Player.State.MOVE:
		return
	var gap := _vamp.global_position.x - _player.global_position.x
	var toward := "move_right" if gap > 0.0 else "move_left"
	var away := "move_left" if gap > 0.0 else "move_right"
	var dist := absf(gap)
	match _vamp.move:
		Vampire.Move.DIVE:
			# Пике летит туда, где герой стоял: перекат в сторону.
			Input.action_press(away if dist > 1.0 else toward)
			Input.action_press("roll")
			_cooldown = 0.6
		Vampire.Move.BAT_SWOOP:
			if dist < 3.2 and _player.is_on_floor():
				Input.action_press("jump")
				_cooldown = 0.5
		Vampire.Move.NONE:
			if _vamp.state == Dummy.State.RECOVER and dist < 6.0:
				# Окно после посадки: подбежать и ударить.
				if dist > 1.6:
					Input.action_press(toward)
				else:
					_player.facing = signf(gap)
					Input.action_press("attack")
					_cooldown = 0.3
			elif dist < 5.0:
				Input.action_press(away)
