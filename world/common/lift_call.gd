class_name LiftCall
extends Interactable
## Рычаг вызова подъёмника (Lift) на остановке (§8.13): площадка у другой остановки — едет сюда.
## Ставит сам Lift — по рычагу на каждую остановку.

var lift: Lift
## Рычаг у верхней остановки.
var top := false


func _ready() -> void:
	super()
	prompt = "Вызвать подъёмник"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.4, 2.4)
	shape.shape = box
	shape.position.y = 1.2
	add_child(shape)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09, 0.09, 0.1)
	iron.roughness = 0.6
	iron.metallic = 0.4
	for part: Array in [[Vector3(0.0, 0.5, -0.9), Vector3(0.12, 1.0, 0.12), 0.0], [Vector3(0.12, 1.15, -0.9), Vector3(0.07, 0.6, 0.07), -0.5]]:
		var mesh := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = part[1]
		bar.material = iron
		mesh.mesh = bar
		mesh.position = part[0]
		mesh.rotation.z = part[2]
		add_child(mesh)


func interact(_by: Player) -> void:
	if lift:
		lift.call_here(top)
