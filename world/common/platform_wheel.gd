class_name PlatformWheel
extends Node3D
## Огромное колесо с площадками-люльками (§8.13, водоотливное колесо копей): колесо медленно вращается
## за плоскостью героя, на его ободе висят люльки — они всегда ровные, герой запрыгивает на них и едет.
## Направление: speed < 0 — по часовой стрелке в кадре (западный край поднимается, восточный опускается).
## Узел стоит в оси колеса. На карте колесо — воздух круга радиусом obod + запас (MapShapes).

const WOOD := Color(0.34, 0.24, 0.15)
const WOOD_DARK := Color(0.2, 0.14, 0.09)
const IRON := Color(0.09, 0.09, 0.1)

@export var radius := 8.0
@export var cradles := 6
## Угловая скорость, рад/с; знак — направление. −0.157 — оборот за 40 с.
@export var speed := -0.157
## Насколько люлька висит ниже точки подвеса на ободе, м.
@export var hang := 0.9
@export var cradle_size := Vector3(2.4, 0.35, 2.4)
## Где само колесо (обод и спицы) по глубине — позади героя.
@export var wheel_z := -1.7
## Начальный поворот колеса, рад.
@export var start_angle := 0.0

var angle := 0.0
var _wheel: Node3D
var _cradles: Array[AnimatableBody3D] = []


func _ready() -> void:
	angle = start_angle
	var wood := _material(WOOD)
	var dark := _material(WOOD_DARK)
	var iron := _material(IRON)
	_wheel = Node3D.new()
	_wheel.name = &"Wheel"
	_wheel.position.z = wheel_z
	add_child(_wheel)
	var segments := 24
	for i in segments:
		var a := TAU * i / segments
		var rim := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(TAU * radius / segments + 0.12, 0.45, 0.5)
		box.material = wood
		rim.mesh = box
		rim.position = Vector3(cos(a) * radius, sin(a) * radius, 0.0)
		rim.rotation.z = a + PI * 0.5
		_wheel.add_child(rim)
		# Лопатки-черпаки по ободу: колесо водоотливное.
		var bucket := MeshInstance3D.new()
		var bucket_box := BoxMesh.new()
		bucket_box.size = Vector3(0.7, 0.5, 0.9)
		bucket_box.material = wood
		bucket.mesh = bucket_box
		bucket.position = Vector3(cos(a) * (radius + 0.4), sin(a) * (radius + 0.4), -0.1)
		bucket.rotation.z = a
		_wheel.add_child(bucket)
	for i in cradles * 2:
		var a := TAU * i / (cradles * 2)
		var spoke := MeshInstance3D.new()
		var spoke_box := BoxMesh.new()
		spoke_box.size = Vector3(radius, 0.22, 0.22)
		spoke_box.material = dark
		spoke.mesh = spoke_box
		spoke.position = Vector3(cos(a) * radius * 0.5, sin(a) * radius * 0.5, 0.05)
		spoke.rotation.z = a
		_wheel.add_child(spoke)
	var hub := MeshInstance3D.new()
	var axle := CylinderMesh.new()
	axle.top_radius = 0.7
	axle.bottom_radius = 0.7
	axle.height = 1.4
	axle.material = iron
	hub.mesh = axle
	hub.rotation.x = PI * 0.5
	_wheel.add_child(hub)
	for i in cradles:
		var cradle := AnimatableBody3D.new()
		cradle.name = "Cradle%d" % i
		cradle.sync_to_physics = true
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = cradle_size
		shape.shape = collision
		cradle.add_child(shape)
		_mesh(cradle, Vector3.ZERO, cradle_size, wood)
		# Подвес люльки к ободу: две тяги вверх, к точке на ободе позади.
		for side: float in [-1.0, 1.0]:
			_mesh(cradle, Vector3(side * (cradle_size.x * 0.5 - 0.1), hang * 0.5, wheel_z * 0.6), Vector3(0.07, hang, 0.07), iron)
		_mesh(cradle, Vector3(0.0, hang, wheel_z * 0.6), Vector3(cradle_size.x, 0.08, 0.08), iron)
		add_child(cradle)
		_cradles.append(cradle)
	_place()


func _physics_process(delta: float) -> void:
	angle = wrapf(angle + speed * delta, -PI, PI)
	_place()


## Где сейчас верх люльки i (м от оси колеса).
func cradle_top(i: int) -> Vector3:
	return _cradles[i].position + Vector3(0.0, cradle_size.y * 0.5, 0.0)


func cradle_count() -> int:
	return _cradles.size()


func _place() -> void:
	_wheel.rotation.z = angle
	for i in _cradles.size():
		var a := angle + TAU * i / _cradles.size()
		_cradles[i].position = Vector3(cos(a) * radius, sin(a) * radius - hang, 0.0)


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
