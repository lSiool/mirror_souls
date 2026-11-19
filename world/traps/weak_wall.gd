class_name WeakWall
extends StaticBody3D
## Слабая стена (§8.14): трухлявая кладка или заколоченный ход. Валун (RollingBoulder) проламывает её и открывает
## новый ход; проломленная остаётся проломленной навсегда (флаг мира). Выглядит чуть иначе, чем крепкая стена:
## щели, доски, осыпь у подножия — внимательный заметит. Узел стоит на полу посередине стены.

const LOOK := Color(0.28, 0.24, 0.2)

@export var size := Vector3(1.2, 3.0, 4.4)
## Флаг мира: стена проломлена. Пусто — после отдыха стена снова целая.
@export var flag: StringName
@export var look_color := LOOK

var broken := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = look_color
	material.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.03)
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	wall.mesh = mesh
	wall.position.y = size.y * 0.5
	add_child(wall)
	# Трещины и щели на лицевой стороне, осыпь у подножия.
	for i in 3:
		var crack := MeshInstance3D.new()
		var crack_box := BoxMesh.new()
		crack_box.size = Vector3(0.05, size.y * (0.35 + 0.15 * i), 0.02)
		crack_box.material = dark
		crack.mesh = crack_box
		crack.position = Vector3(-size.x * 0.3 + i * size.x * 0.3, size.y * (0.35 + 0.1 * i), size.z * 0.5 + 0.01)
		crack.rotation.z = 0.25 * (i - 1)
		add_child(crack)
	var rubble := MeshInstance3D.new()
	var rubble_box := BoxMesh.new()
	rubble_box.size = Vector3(size.x + 0.8, 0.25, 1.0)
	rubble_box.material = material
	rubble.mesh = rubble_box
	rubble.position = Vector3(0.0, 0.12, size.z * 0.5 - 0.3)
	add_child(rubble)
	if flag != &"" and GameState.has_flag(flag):
		_remove()


## Проломить: обломки, пыль, ход открыт.
func smash() -> void:
	if broken:
		return
	if flag != &"":
		GameState.set_flag(flag)
	Sfx.play(&"prop_break_wood", global_position + Vector3(0.0, size.y * 0.5, 0.0))
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, size.y * 0.5, 0.5), look_color.lightened(0.3), 30)
	_remove()


func _remove() -> void:
	broken = true
	visible = false
	collision_layer = 0
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", true)
