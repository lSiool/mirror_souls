class_name BossArena
extends Node3D
## Арена босса: когда бой начинается (Events.boss_engaged), по краям встают туманные стены;
## когда босс побеждён или ушёл — растворяются. Побеждённый босс стен не ставит.

@export var boss_path: NodePath
@export var left_x := -12.0
@export var right_x := 12.0
@export var height := 8.0

var gates: Array[FogGate] = []
var _boss: Dummy


func _ready() -> void:
	add_to_group("boss_arena")
	_boss = get_node_or_null(boss_path) as Dummy
	if _boss == null or _boss.is_queued_for_deletion():
		return
	Events.boss_engaged.connect(_on_boss_engaged)
	_boss.health.died.connect(lower)
	_boss.tree_exiting.connect(lower)


func is_closed() -> bool:
	return not gates.is_empty() and gates[0].is_up()


func _on_boss_engaged(who: Dummy) -> void:
	if who != _boss or not gates.is_empty():
		return
	for x in [left_x, right_x]:
		var gate := FogGate.new()
		gate.height = height
		add_child(gate)
		gate.global_position = Vector3(x, global_position.y, 0.0)
		gate.rise()
		gates.append(gate)


func flare() -> void:
	for gate in gates:
		gate.flare()


func lower() -> void:
	for gate in gates:
		if is_instance_valid(gate):
			gate.dissolve()
