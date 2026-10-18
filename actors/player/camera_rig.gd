class_name CameraRig
extends Node3D
## Боковая камера с лёгким наклоном сверху (как у Mandragora). Следует за целью
## со сглаживанием и заглядывает вперёд по направлению взгляда героя.

@export var target_path: NodePath
@export_range(0.0, 30.0) var pitch_deg := 9.0
@export var distance := 15.0
@export var height_offset := 1.4
@export var look_ahead := 1.6
@export var follow_speed := 6.0
@export var fov := 45.0

var _target: Node3D
var _look := 0.0
var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_duration := 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_target = get_node_or_null(target_path)
	camera.fov = fov
	Events.camera_shake_requested.connect(shake)
	snap_to_target()


func _process(delta: float) -> void:
	if _target == null:
		return
	var player := _target as Player
	var facing := player.facing if player else 1.0
	_look = lerpf(_look, facing * look_ahead, 1.0 - exp(-2.5 * delta))
	global_position = global_position.lerp(_focus(), 1.0 - exp(-follow_speed * delta))

	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	var shake_offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		var k := _shake_strength * (_shake_time / _shake_duration)
		shake_offset = Vector3(randf_range(-k, k), randf_range(-k, k), 0.0)
	camera.position = offset + shake_offset
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func shake(strength: float, duration: float) -> void:
	if strength < _shake_strength * (_shake_time / maxf(_shake_duration, 0.001)):
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_time = duration


func snap_to_target() -> void:
	if _target:
		global_position = _focus()


func _focus() -> Vector3:
	return _target.global_position + Vector3(_look, height_offset, 0.0)
