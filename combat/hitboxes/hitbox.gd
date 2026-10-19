class_name Hitbox
extends Area3D
## Наносит урон пересекающимся Hurtbox, пока активен. Одна цель — один удар за активацию.

signal hit_landed(hurtbox: Hurtbox)

@export var damage := 10.0
## Урон по стойкости цели.
@export var poise_damage := 15.0
@export var knockback := 6.0
@export var heavy := false
@export var non_lethal := false
@export var active := false:
	set(value):
		if value and not active:
			_already_hit.clear()
		active = value

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox in _already_hit:
			continue
		if hurtbox.receive_hit(self):
			_already_hit.append(hurtbox)
			hit_landed.emit(hurtbox)


func knockback_direction(target: Node3D) -> Vector3:
	var dx := signf(target.global_position.x - global_position.x)
	if dx == 0.0:
		dx = 1.0
	return Vector3(dx, 0.0, 0.0)
