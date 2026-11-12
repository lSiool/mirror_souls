class_name BossArena
extends Node3D
## Арена босса: когда бой начинается (Events.boss_engaged), по краям встают туманные стены;
## когда босс побеждён или ушёл — растворяются. Побеждённый босс стен не ставит.
## С арены не сбежать (2026-11-11): стена встаёт не мгновенно, и герой успевал выскочить за неё —
## бой начинался, а он оставался снаружи. Теперь, пока арена закрыта, героя, оказавшегося
## за стеной, туман сразу переносит внутрь (сквозь саму стену его не протащить — её тело
## выталкивает обратно). Внутри держит сама стена.

## Куда туман ставит героя — на столько внутрь от стены.
const PULL_IN := 1.0
const PULL_TINT := Color(0.55, 0.5, 0.85)

@export var boss_path: NodePath
@export var left_x := -12.0
@export var right_x := 12.0
@export var height := 8.0

var gates: Array[FogGate] = []
var _boss: Dummy
var _closed := false
var _player: Player


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
	_closed = true
	_player = get_tree().get_first_node_in_group(&"player") as Player


func _physics_process(_delta: float) -> void:
	if not _closed or _player == null or not is_instance_valid(_player) or _player.is_dead():
		return
	var x := _player.global_position.x
	if x >= left_x and x <= right_x:
		return
	# За стеной: туман переносит внутрь, скорость наружу гасится.
	var inside := left_x + PULL_IN if x < left_x else right_x - PULL_IN
	_player.teleport(Vector3(inside, _player.global_position.y, 0.0))
	HitSpark.spawn(get_parent(), _player.global_position + Vector3(0.0, 1.0, 0.3), PULL_TINT, 18)


func flare() -> void:
	for gate in gates:
		gate.flare()


func lower() -> void:
	_closed = false
	for gate in gates:
		if is_instance_valid(gate):
			gate.dissolve()
