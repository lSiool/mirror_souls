class_name BoundCaptive
extends Interactable
## Связанный пленник: развязать — флаг мира, короткая благодарность, и он уходит своей дорогой
## (Травница возвращается к часовне, §8.9). Развязанного больше не встретить здесь.

@export var flag: StringName
@export var captive_name := "Пленница"
@export var free_prompt := "Развязать"
@export var thanks := PackedStringArray()
@export var look_color := Color(0.22, 0.26, 0.2)


func _ready() -> void:
	super()
	if GameState.has_flag(flag):
		queue_free()
		return
	prompt = free_prompt
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.0, 2.6)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = look_color
	# Сидит в углу, сжавшись: тело ниже и наклонено.
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.1
	capsule.material = material
	body.mesh = capsule
	body.position = Vector3(0.0, 0.55, -1.2)
	body.rotation.z = 0.25
	add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.material = material
	head.mesh = sphere
	head.position = Vector3(0.18, 1.12, -1.2)
	add_child(head)
	var rope_material := StandardMaterial3D.new()
	rope_material.albedo_color = Color(0.55, 0.45, 0.3)
	for y in [0.45, 0.7]:
		var rope := MeshInstance3D.new()
		var band := BoxMesh.new()
		band.size = Vector3(0.72, 0.06, 0.72)
		band.material = rope_material
		rope.mesh = band
		rope.position = Vector3(0.0, y, -1.2)
		add_child(rope)


func interact(_by: Player) -> void:
	GameState.set_flag(flag)
	enabled = false
	for line in thanks:
		Events.message.emit("%s: %s" % [captive_name, line])
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 0.0, 1.0), 0.6).set_delay(1.0)
	tween.tween_callback(queue_free)
