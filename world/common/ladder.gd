class_name Ladder
extends Area3D
## Лестница: стоя рядом, герой жмёт «вверх» и лезет. Наверху сам подтягивается на этаж (exit_dir).

const LAYER_PLAYER := 1 << 1

@export var height := 4.0
## В какую сторону сойти наверху: -1 влево, 1 вправо.
@export var exit_dir := -1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, height + 0.6, 2.0)
	shape.shape = box
	shape.position.y = height * 0.5 + 0.3
	add_child(shape)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.33, 0.22, 0.13)
	for side: float in [-0.32, 0.32]:
		_part(Vector3(side, height * 0.5, -0.45), Vector3(0.08, height + 0.3, 0.08), wood)
	var rungs := int(height / 0.45)
	for i in rungs:
		_part(Vector3(0.0, 0.3 + i * 0.45, -0.45), Vector3(0.64, 0.06, 0.06), wood)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Выше этого герой уже на этаже.
func top_y() -> float:
	return global_position.y + height + 0.05


func _part(at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.ladder = self


func _on_body_exited(body: Node3D) -> void:
	if body is Player and body.ladder == self:
		body.ladder = null
