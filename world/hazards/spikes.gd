class_name Spikes
extends Hitbox
## Шипы: ловушка, которая убивает. Ширина задаётся в инспекторе, меши и форма строятся сами.

@export var width := 4.0
@export var spike_height := 0.6


func _ready() -> void:
	super()
	collision_layer = 0
	collision_mask = 1 << 1
	damage = 999.0
	knockback = 0.0
	active = true

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, spike_height * 0.7, 1.6)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = spike_height * 0.35
	add_child(collision)

	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.16
	spike_mesh.height = spike_height
	spike_mesh.radial_segments = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.52, 0.5)
	mat.metallic = 0.8
	mat.roughness = 0.35
	spike_mesh.material = mat
	var count := maxi(int(width / 0.35), 1)
	for row in [-0.35, 0.35]:
		for i in count:
			var spike := MeshInstance3D.new()
			spike.mesh = spike_mesh
			spike.position = Vector3(-width * 0.5 + (i + 0.5) * width / count, spike_height * 0.5, row)
			add_child(spike)
