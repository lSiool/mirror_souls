extends Node
## Видео встречи с оборотнем на площади (§9.2, 2026-11-16): склонился над жертвой → заметил героя
## (рык, Zombie Scream) → бой → катсцена: прыжок, терзает, зов из леса, уходит. Бот за героя с бруском:
## подходит, бьёт в окна после удара зверя, на прыжке уходит перекатом. Урон по герою обычный —
## бой кончается катсценой, когда герой обессилел (SquareEvent).
## "/c/Program Files/Godot/Godot.exe" --path . --write-movie out.avi --fixed-fps 30 res://tools/video/werewolf_video.tscn

const LENGTH := 60.0
## Сколько стоит поодаль, прежде чем подойти: видно, как зверь рвёт жертву.
const LOOK_TIME := 2.5

var _main: Node
var _player: Player
var _rooms: RoomManager
var _wolf: Werewolf
var _time := 0.0
var _cooldown := 0.0
var _running := false
var _after := -1.0


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"stick"
	GameState.set_flag(&"got_stick")
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	await _wait(2.0)
	_rooms = _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	_rooms.hud.popup.blocks_interact = false
	await _rooms.travel(&"village_square", ^"Spawns/FromHouse")
	await _wait(0.4)
	_rooms.hud.popup.queue.clear()
	_rooms.hud.popup.dismiss()
	_wolf = _rooms.current_room.get_node("Objects/Werewolf") as Werewolf
	_player.teleport(Vector3(_wolf.global_position.x - 13.0, _wolf.global_position.y + 0.1, 0.0))
	_player.facing = 1.0
	_running = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	_cooldown -= delta
	if _time > LENGTH or not is_instance_valid(_wolf):
		get_tree().quit()
		return
	for a in ["move_left", "move_right", "attack", "roll", "jump"]:
		Input.action_release(a)
	if _wolf.in_scene or _wolf._called:
		# Катсцена: ждём, пока зверь уйдёт, и ещё немного.
		if _after < 0.0 and _wolf._fleeing:
			_after = _time
		if _after >= 0.0 and _time - _after > 2.5:
			get_tree().quit()
		return
	if _time < LOOK_TIME or _cooldown > 0.0 or _player.state != Player.State.MOVE:
		return
	var gap := _wolf.global_position.x - _player.global_position.x
	var toward := "move_right" if gap > 0.0 else "move_left"
	var away := "move_left" if gap > 0.0 else "move_right"
	var dist := absf(gap)
	if not _wolf.engaged or _wolf.state == Dummy.State.DORMANT:
		# Подходит, пока зверь не заметил; во время рыка стоит.
		if not _wolf.engaged and dist > 6.5:
			Input.action_press(toward)
		return
	match _wolf.state:
		Dummy.State.WINDUP:
			if _wolf.move == Werewolf.Move.LEAP or (dist < 2.2 and randf() < 0.5):
				Input.action_press(away)
				Input.action_press("roll")
				_cooldown = 0.6
		Dummy.State.RECOVER:
			if dist > 1.5:
				Input.action_press(toward)
			else:
				_player.facing = signf(gap)
				Input.action_press("attack")
				_cooldown = 0.35
		_:
			if dist > 2.5:
				Input.action_press(toward)
