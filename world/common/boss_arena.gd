class_name BossArena
extends Node3D
## Арена босса: когда бой начинается, по краям встают туманные стены; когда босс побеждён или
## ушёл — растворяются. Побеждённый босс стен не ставит.
##
## Вступление-катсцена (2026-11-12, по предложению автора): босс, у которого есть вступление,
## шлёт Events.boss_intro. Тогда стены встают сразу, сцена забирает управление (герой замирает
## лицом к боссу), камера отъезжает и держит обоих, сверху и снизу — кинополосы. Управление
## возвращается с Events.boss_engaged, когда босс встал. Так стена уже стоит, пока герой не может
## двигаться, и выйти за неё до начала боя нельзя. Босс без вступления закрывает арену
## по boss_engaged, как раньше.
## Страховка (2026-11-11): пока арена закрыта, героя, оказавшегося за стеной, туман сразу
## переносит внутрь (сквозь саму стену его не протащить — её тело выталкивает обратно).

## Куда туман ставит героя — на столько внутрь от стены.
const PULL_IN := 1.0
const PULL_TINT := Color(0.55, 0.5, 0.85)
## Камера на вступлении: отъезд и время переходов.
const INTRO_ZOOM := 1.25
const INTRO_BLEND := 0.6
## Если босс так и не встал (сцена прервана) — управление вернётся само через столько секунд.
const INTRO_MAX := 8.0

@export var boss_path: NodePath
@export var left_x := -12.0
@export var right_x := 12.0
@export var height := 8.0

var gates: Array[FogGate] = []
var _boss: Dummy
var _closed := false
var _player: Player
## Идёт вступление: герой в руках сцены.
var in_intro := false
var _intro_t := 0.0


func _ready() -> void:
	add_to_group("boss_arena")
	_boss = get_node_or_null(boss_path) as Dummy
	if _boss == null or _boss.is_queued_for_deletion():
		return
	Events.boss_intro.connect(_on_boss_intro)
	Events.boss_engaged.connect(_on_boss_engaged)
	_boss.health.died.connect(lower)
	_boss.tree_exiting.connect(lower)


func is_closed() -> bool:
	return not gates.is_empty() and gates[0].is_up()


func _on_boss_intro(who: Dummy) -> void:
	if who != _boss or in_intro:
		return
	_close()
	if _player == null or _player.is_dead():
		return
	in_intro = true
	_intro_t = 0.0
	_pull_inside()
	_player.facing = signf(_boss.global_position.x - _player.global_position.x)
	_player.knock_down(false)
	var rig := _camera()
	if rig:
		var mid := (_player.global_position + _boss.global_position) * 0.5
		rig.hold(mid + Vector3(0.0, rig.height_offset + 0.6, 0.0), INTRO_BLEND)
		rig.zoom(INTRO_ZOOM, INTRO_BLEND)
	Events.cinematic_bars.emit(true)


func _on_boss_engaged(who: Dummy) -> void:
	if who != _boss:
		return
	_close()
	_end_intro()


func _close() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if not gates.is_empty():
		return
	for x in [left_x, right_x]:
		var gate := FogGate.new()
		gate.height = height
		add_child(gate)
		gate.global_position = Vector3(x, global_position.y, 0.0)
		gate.rise()
		gates.append(gate)
	_closed = true


func _end_intro() -> void:
	if not in_intro:
		return
	in_intro = false
	if is_instance_valid(_player) and not _player.is_dead():
		_player.stand_up()
	var rig := _camera()
	if rig:
		rig.release_hold(INTRO_BLEND)
		rig.zoom(1.0, INTRO_BLEND)
	Events.cinematic_bars.emit(false)


func _camera() -> CameraRig:
	return get_tree().get_first_node_in_group(&"camera_rig") as CameraRig


func _physics_process(delta: float) -> void:
	if in_intro:
		_intro_t += delta
		if _intro_t >= INTRO_MAX:
			_end_intro()
	if not _closed or _player == null or not is_instance_valid(_player) or _player.is_dead():
		return
	_pull_inside()


## За стеной: туман переносит внутрь, скорость наружу гасится.
func _pull_inside() -> void:
	var x := _player.global_position.x
	if x >= left_x and x <= right_x:
		return
	var inside := left_x + PULL_IN if x < left_x else right_x - PULL_IN
	_player.teleport(Vector3(inside, _player.global_position.y, 0.0))
	HitSpark.spawn(get_parent(), _player.global_position + Vector3(0.0, 1.0, 0.3), PULL_TINT, 18)


func flare() -> void:
	for gate in gates:
		gate.flare()


func lower() -> void:
	_closed = false
	_end_intro()
	for gate in gates:
		if is_instance_valid(gate):
			gate.dissolve()
