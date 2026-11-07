class_name Note
extends Interactable
## Записка, письмо, надпись: прочитать можно сколько угодно раз. Мир рассказывает без диалогов.

@export var title := "Записка"
## Текст: каждая строка — отдельная строка на экране.
@export var lines := PackedStringArray()


func _ready() -> void:
	super()
	prompt = "Прочитать: %s" % title
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.0, 2.4)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)
	var paper := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.4, 0.03, 0.3)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.72, 0.6)
	material.emission_enabled = true
	material.emission = Color(0.78, 0.72, 0.6)
	material.emission_energy_multiplier = 0.25
	sheet.material = material
	paper.mesh = sheet
	paper.position = Vector3(0.0, 0.03, -0.3)
	paper.rotation.y = 0.3
	add_child(paper)


func interact(_by: Player) -> void:
	Events.message.emit("%s\n%s" % [title, "\n".join(lines)])
