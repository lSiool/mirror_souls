extends Node3D
## Кладбище (§8.9, кадр 1.2): когда герой подходит, дверь второго склепа распахивается и наружу
## выбегают двое мародёров с добычей — подсвечник и мешок. Свидетель им не нужен: начинается бой.
## Побеждённые не возвращаются до отдыха (как все враги); сцена играет, пока они живы.

const RUN_OUT := 0.8

@export var trigger_x := 0.0
## Куда выбегают из двери: смещения по X для первого и второго.
@export var landing := Vector2(1.5, 3.2)
@export var door_path: NodePath

var _done := false
var _robbers: Array[Bandit] = []
var _player: Node3D


func _ready() -> void:
	for child in get_parent().get_children():
		if child is Bandit:
			_robbers.append(child)
	for robber in _robbers:
		robber.visible = false


func _process(_delta: float) -> void:
	if _done:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if _player.global_position.x > trigger_x:
		_done = true
		_burst_out()


func _burst_out() -> void:
	var door := get_node_or_null(door_path) as Node3D
	if door:
		var swing := create_tween()
		swing.tween_property(door, "rotation:y", -1.6, 0.25).set_trans(Tween.TRANS_BACK)
	Events.camera_shake_requested.emit(0.25, 0.25)
	Sfx.play(&"sword_block", global_position, -4.0)
	for i in _robbers.size():
		var robber := _robbers[i]
		if not is_instance_valid(robber):
			continue
		var goal := robber.global_position + Vector3(landing[mini(i, 1)], 0.0, 0.0)
		robber.global_position = global_position + Vector3(0.0, 0.0, -1.6)
		robber.visible = true
		var run := robber.create_tween()
		run.tween_property(robber, "global_position", Vector3(goal.x, goal.y, 0.0), RUN_OUT).set_delay(i * 0.25)
	Events.message.emit("Мародёры: «Свидетель! Не дай ему уйти!»")
	await get_tree().create_timer(RUN_OUT + 0.6).timeout
	for robber in _robbers:
		if is_instance_valid(robber):
			robber.wake()
