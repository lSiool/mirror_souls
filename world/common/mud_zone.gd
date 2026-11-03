class_name MudZone
extends Area3D
## Болотная грязь (§8.9, кадр 5): герой в ней ходит медленнее, прыгает ниже, кувырок короче
## и в бою дороже (Player.MUD_*). Сверху — блестящая чёрная жижа.

const LAYER_PLAYER := 1 << 1

@export var size := Vector3(10.0, 1.0, 4.4)
@export var look_color := Color(0.06, 0.055, 0.035)


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	var surface := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(size.x, 0.06, size.z)
	var material := StandardMaterial3D.new()
	material.albedo_color = look_color
	material.roughness = 0.12
	material.metallic = 0.25
	plane.material = material
	surface.mesh = plane
	surface.position.y = 0.04
	add_child(surface)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.mud_zones += 1


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		body.mud_zones = maxi(body.mud_zones - 1, 0)
