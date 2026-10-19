class_name ArrowPeg
extends Area3D
## Стрела, воткнутая в мягкую поверхность, — ступенька на один прыжок (§6.2).
## Работает только одна: новая заменяет старую, иначе стрелами можно забраться куда угодно.

const RADIUS := 0.6

static var current: ArrowPeg

## Нормаль поверхности, куда воткнута стрела: от неё герой отталкивается.
var normal := Vector3.LEFT


static func plant(parent: Node, at: Vector3, surface_normal: Vector3) -> ArrowPeg:
	if is_instance_valid(current):
		current.break_off()
	var peg := ArrowPeg.new()
	peg.normal = surface_normal
	parent.add_child(peg)
	peg.global_position = at
	current = peg
	return peg


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = normal * 0.3
	add_child(collision)
	var shaft := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.04, 0.04)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.25)
	mesh.material = wood
	shaft.mesh = mesh
	shaft.position = normal * 0.3
	shaft.rotation.z = atan2(normal.y, normal.x)
	add_child(shaft)
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			body.set_peg(self))
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			body.clear_peg(self))


## Колышек сломался (от него оттолкнулись или воткнули новый) — падает и исчезает.
func break_off() -> void:
	if current == self:
		current = null
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 1.5, 0.4).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
