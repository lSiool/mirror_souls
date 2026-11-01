class_name EchoDrop
extends Node3D
## Отзвук прошлого рядового врага: голубая стеклянная капля всплывает над телом, замирает
## и сама летит к герою — поглощается без нажатия кнопки. Счётчик в HUD прибавляется
## в момент касания. Отзвуки боссов и самого героя так не летят — их берут касанием.

const RISE_TIME := 0.45
const HOVER_TIME := 0.25
const RISE_HEIGHT := 0.9
const FLY_ACCEL := 40.0
const FLY_MAX_SPEED := 22.0
const ABSORB_DISTANCE := 0.35
const COLOR := Color(0.45, 0.72, 1.0)

var amount := 0
var _target: Node3D
var _time := 0.0
var _velocity := Vector3.ZERO
var _start := Vector3.ZERO
var _absorbed := false


static func spawn(parent: Node, at: Vector3, value: int, target: Node3D) -> EchoDrop:
	var drop := EchoDrop.new()
	drop.amount = value
	drop._target = target
	parent.add_child(drop)
	drop.global_position = at
	drop._start = at
	return drop


## Капля без валюты, просто летит из точки в точку: отзвуки текут в отражение (§8.6).
static func stream(parent: Node, from: Vector3, to: Vector3, time: float) -> void:
	var drop := EchoDrop.new()
	drop._absorbed = true
	drop.set_process(false)
	parent.add_child(drop)
	drop.global_position = from
	var tween := drop.create_tween()
	tween.tween_property(drop, "global_position", to, time).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(drop.queue_free)


func _ready() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(COLOR, 0.75)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = COLOR
	glass.emission_energy_multiplier = 2.5
	glass.rim_enabled = true
	glass.rim = 1.0
	# Капля: шарик снизу, конус-хвостик сверху.
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.material = glass
	ball.mesh = sphere
	add_child(ball)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.085
	cone.height = 0.2
	cone.material = glass
	tip.mesh = cone
	tip.position.y = 0.12
	add_child(tip)
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 0.8
	light.omni_range = 1.6
	add_child(light)


func _process(delta: float) -> void:
	_time += delta
	if _time < RISE_TIME:
		var k := _time / RISE_TIME
		global_position = _start + Vector3(0.0, RISE_HEIGHT * (1.0 - (1.0 - k) * (1.0 - k)), 0.0)
		return
	if _time < RISE_TIME + HOVER_TIME or not is_instance_valid(_target):
		rotate_y(delta * 3.0)
		return
	var goal := _target.global_position + Vector3(0.0, 1.1, 0.0)
	var to_goal := goal - global_position
	if to_goal.length() < ABSORB_DISTANCE:
		_absorb()
		return
	_velocity = (_velocity + to_goal.normalized() * FLY_ACCEL * delta).limit_length(FLY_MAX_SPEED)
	# Тянется к герою, не пролетая мимо: скорость поворачивает к цели.
	_velocity = _velocity.slerp(to_goal.normalized() * _velocity.length(), minf(1.0, 6.0 * delta))
	global_position += _velocity * delta


func _absorb() -> void:
	_absorbed = true
	GameState.add_echoes(amount)
	Sfx.play(&"glass_glint", global_position, -10.0)
	HitSpark.spawn(get_parent(), global_position, COLOR, 10)
	queue_free()


## Комнату пересоздали, пока капля летела (смерть, отдых): отзвук всё равно засчитан.
func _exit_tree() -> void:
	if not _absorbed and not is_queued_for_deletion():
		_absorbed = true
		GameState.add_echoes(amount)
