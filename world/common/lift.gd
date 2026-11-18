class_name Lift
extends Node3D
## Подъёмник копей (§8.13): площадка ходит между двумя остановками — внизу (точка узла) и на travel выше.
## Как подъёмники в Dark Souls: встал на площадку — через миг она едет к другой остановке; доехал — стоит,
## пока герой не сойдёт и не встанет снова. На каждой остановке рычаг вызова (LiftCall): площадка
## у другой остановки — едет к герою. Положение не сохраняется: при заходе в комнату — start_top.
## На карте шахта подъёмника рисуется как шахта лестницы (MapShapes).

const LAYER_PLAYER := 1 << 1
const WOOD := Color(0.25, 0.17, 0.11)
const IRON := Color(0.09, 0.09, 0.1)

@export var travel := 12.0
@export var start_top := true
@export var speed := 3.2
## Площадка: ширина, толщина, глубина.
@export var size := Vector3(3.4, 0.4, 2.4)
## Сколько стоять на площадке, пока она тронется, с.
@export var wait := 0.6
## Где рычаги вызова от середины шахты по x (знак — сторона): у верхней и у нижней остановки свой пол.
@export var call_top_x := -2.6
@export var call_bottom_x := 2.6

var at_top := true
var moving := false
var _platform: AnimatableBody3D
var _target := 0.0
var _rider := false
var _must_leave := false
var _wait_t := 0.0


func _ready() -> void:
	at_top = start_top
	_platform = AnimatableBody3D.new()
	_platform.name = &"Platform"
	_platform.sync_to_physics = true
	_platform.position.y = _stop_y(at_top)
	add_child(_platform)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	_platform.add_child(shape)
	var wood := _material(WOOD)
	var iron := _material(IRON)
	_mesh(_platform, Vector3.ZERO, size, wood)
	_mesh(_platform, Vector3(0.0, 0.5, -size.z * 0.5 + 0.06), Vector3(size.x, 0.08, 0.08), wood)
	# Цепи к вороту копра: уходят вверх с площадкой.
	for side: float in [-1.0, 1.0]:
		var length := travel + 6.0
		_mesh(_platform, Vector3(side * (size.x * 0.5 - 0.15), length * 0.5, -0.3), Vector3(0.07, length, 0.07), iron)
	var rider := Area3D.new()
	rider.collision_layer = 0
	rider.collision_mask = LAYER_PLAYER
	rider.monitorable = false
	var rider_shape := CollisionShape3D.new()
	var rider_box := BoxShape3D.new()
	rider_box.size = Vector3(size.x - 0.4, 1.2, size.z)
	rider_shape.shape = rider_box
	rider_shape.position.y = size.y * 0.5 + 0.6
	rider.add_child(rider_shape)
	_platform.add_child(rider)
	rider.body_entered.connect(func(body: Node3D) -> void: if body is Player: _rider = true)
	rider.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_rider = false
			_must_leave = false)
	for top: bool in [false, true]:
		var lever := LiftCall.new()
		lever.lift = self
		lever.top = top
		lever.position = Vector3(call_top_x if top else call_bottom_x, travel if top else 0.0, 0.0)
		add_child(lever)


func _physics_process(delta: float) -> void:
	if moving:
		_platform.position.y = move_toward(_platform.position.y, _target, speed * delta)
		if is_equal_approx(_platform.position.y, _target):
			moving = false
			at_top = _target > 0.0
			_must_leave = _rider
			_wait_t = 0.0
		return
	if _rider and not _must_leave:
		_wait_t += delta
		if _wait_t >= wait:
			_go(not at_top)
	else:
		_wait_t = 0.0


## Рычаг на остановке: площадка у другой остановки — едет сюда.
func call_here(top: bool) -> void:
	if not moving and at_top != top:
		_go(top)


## Где сейчас верх площадки, м от точки узла.
func deck_y() -> float:
	return _platform.position.y + size.y * 0.5


func _go(top: bool) -> void:
	_target = _stop_y(top)
	moving = true


func _stop_y(top: bool) -> float:
	return (travel if top else 0.0) - size.y * 0.5


func _mesh(parent: Node3D, at: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
