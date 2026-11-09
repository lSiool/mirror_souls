extends Node
## Видео боя с Кузнецом (§6.3): бот играет за героя — подходит, на замахе уходит перекатом,
## бьёт в окна после удара, добивает с колена. Писать — Movie Maker Godot, с рендером:
## xvfb-run Godot --path . --write-movie out.avi --fixed-fps 30 res://tools/video/boss_fight_video.tscn
## Герой не умирает: при малом здоровье пьёт склянку, а урон по нему ослаблен, а ниже трети здоровье тихо доливается.
## Кузнец начинает с START_HP здоровья.

const LENGTH := 72.0
## С какой доли здоровья Кузнец начинает: чтобы за минуту дойти до второй фазы.
const START_HP := 0.62

var _main: Node
var _player: Player
var _rooms: RoomManager
var _smith: Blacksmith
var _time := 0.0
var _cooldown := 0.0
var _fighting := false
var _dead_at := -1.0


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
	await _rooms.travel(&"cursed_village", ^"Spawns/FromSwamp")
	await _wait(0.5)
	_rooms.hud.popup.queue.clear()
	_rooms.hud.popup.dismiss()
	_smith = _rooms.current_room.get_node("Objects/Blacksmith") as Blacksmith
	_player.teleport(Vector3(_smith.global_position.x - 10.0, _smith.global_position.y + 0.1, 0.0))
	_player.facing = 1.0
	await _wait(0.3)
	_player.health.taken_mult = 0.35
	_smith.health.current = _smith.health.max_health * START_HP
	_fighting = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _physics_process(delta: float) -> void:
	if not _fighting:
		return
	_time += delta
	_cooldown -= delta
	if _dead_at < 0.0 and is_instance_valid(_smith) and _smith.health.is_dead():
		_dead_at = _time
	if not is_instance_valid(_smith) or _time > LENGTH or _dead_at >= 0.0 and _time > _dead_at + 5.0:
		get_tree().quit()
		return
	for a in ["move_left", "move_right", "attack", "roll", "heal"]:
		Input.action_release(a)
	if _smith.health.is_dead():
		return
	var hp := _player.health
	if hp.current < hp.max_health * 0.35:
		hp.heal_full()
	var gap := _smith.global_position.x - _player.global_position.x
	var toward := "move_right" if gap > 0.0 else "move_left"
	var away := "move_left" if gap > 0.0 else "move_right"
	var dist := absf(gap)
	var busy := _player.state != Player.State.MOVE
	var st := _smith.state
	if _cooldown > 0.0 or busy:
		return
	# Замах: уйти перекатом, пока удар не начался.
	if st == Dummy.State.WINDUP and dist < 6.0 and _smith._state_time > _smith.windup_time * 0.55:
		Input.action_press(away)
		Input.action_press("roll")
		_cooldown = 0.5
		return
	if st == Dummy.State.ATTACK and dist < 4.5:
		Input.action_press(away)
		return
	# Пьёт склянку на безопасной дистанции.
	if hp.current < hp.max_health * 0.5 and dist > 5.0 and st in [Dummy.State.CHASE, Dummy.State.RECOVER]:
		Input.action_press("heal")
		_cooldown = 1.0
		return
	var open := st in [Dummy.State.RECOVER, Dummy.State.OFF_BALANCE, Dummy.State.CHASE, Dummy.State.DORMANT]
	if dist > 2.0 or st == Dummy.State.DORMANT:
		Input.action_press(toward)
	elif open:
		_player.facing = signf(gap)
		Input.action_press("attack")
		_cooldown = 0.2 if st == Dummy.State.RECOVER else 0.35
