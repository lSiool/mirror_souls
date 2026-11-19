class_name SwingBlade
extends Node3D
## Маятник с лезвием топора (§8.14, груз растяжки): ждёт задранным в щели под потолком — из темноты торчит
## только край лезвия, 10–20 % груза. Спуск (TrapTrigger) — срывается, проходит через ход и качается, затухая;
## потом цепь медленно втягивает его обратно. Бьёт всех на пути — героя и врагов, тяжело, сбивает с ног.
## Узел — точка подвеса; лезвие качается в плоскости героя.

const IRON := Color(0.1, 0.1, 0.11)
const STEEL := Color(0.62, 0.64, 0.68)
## Ниже этой скорости лезвия (м/с) оно уже не ранит.
const HURT_SPEED := 3.0

## От подвеса до середины лезвия, м.
@export var length := 3.4
## Угол ожидания, рад от вертикали; знак — в какую сторону задран (+ — к +x).
@export var rest_angle := 1.35
## Угловая частота качания, рад/с (быстрее настоящего маятника: груз сорван, а не отпущен).
@export var tempo := 2.6
## Затухание качания, 1/с.
@export var damping := 0.45
@export var damage := 45.0
## Сколько качается, прежде чем цепь потянет его наверх, и сколько тянет.
@export var swing_time := 4.0
@export var lift_time := 3.0

var angle := 0.0
var swinging := false

var _t := 0.0
var _lift_from := 0.0
var _arm: Node3D
var _hitbox: Hitbox


func _ready() -> void:
	angle = rest_angle
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.5
	iron.roughness = 0.55
	var steel := StandardMaterial3D.new()
	steel.albedo_color = STEEL
	steel.metallic = 0.9
	steel.roughness = 0.25
	_arm = Node3D.new()
	_arm.name = &"Arm"
	add_child(_arm)
	_box(_arm, Vector3(0.0, -length * 0.5, 0.0), Vector3(0.09, length, 0.09), iron)
	_box(_arm, Vector3.ZERO, Vector3(0.3, 0.3, 0.3), iron)
	# Лезвие топора: обух у тяги, широкое полотно, светлая кромка внизу.
	_box(_arm, Vector3(0.0, -length, 0.0), Vector3(1.15, 0.62, 0.07), iron)
	_box(_arm, Vector3(0.0, -length - 0.33, 0.0), Vector3(1.25, 0.08, 0.05), steel)
	for side: float in [-1.0, 1.0]:
		_box(_arm, Vector3(side * 0.66, -length - 0.18, 0.0), Vector3(0.2, 0.36, 0.05), steel)
	_hitbox = Hitbox.new()
	_hitbox.name = &"Hitbox"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = TrapTrigger.LAYER_PLAYER | TrapTrigger.LAYER_HITTABLE
	_hitbox.damage = damage
	_hitbox.poise_damage = 60.0
	_hitbox.knockback = 9.0
	_hitbox.heavy = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 0.8, 1.6)
	shape.shape = box
	shape.position.y = -length - 0.05
	_hitbox.add_child(shape)
	_arm.add_child(_hitbox)
	_arm.rotation.z = angle


## Сорваться (спуск ловушки). Уже качается — не перезапускается.
func fire() -> void:
	if swinging:
		return
	swinging = true
	_t = 0.0
	Sfx.play(&"trap_release", global_position)


func _physics_process(delta: float) -> void:
	if not swinging:
		return
	_t += delta
	var before := angle
	if _t < swing_time:
		angle = rest_angle * cos(tempo * _t) * exp(-damping * _t)
		_lift_from = angle
	elif _t < swing_time + lift_time:
		var k := (_t - swing_time) / lift_time
		angle = lerpf(_lift_from, rest_angle, k * k * (3.0 - 2.0 * k))
	else:
		angle = rest_angle
		swinging = false
	_arm.rotation.z = angle
	var blade_speed := absf(angle - before) / maxf(delta, 0.0001) * length
	_hitbox.active = _t < swing_time and blade_speed > HURT_SPEED


func _box(parent: Node3D, at: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
