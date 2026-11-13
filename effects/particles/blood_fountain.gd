class_name BloodFountain
extends CPUParticles3D
## Фонтан крови смертельного добивания (§6.1): узкая струя в сторону выдернутого клинка,
## капли падают дугой. Цвет — Dummy.BLEED_COLOR; у стекла, скелетов и духов крови нет —
## их не зовут (Dummy.can_bleed).


static func spawn(parent: Node, at: Vector3, dir: Vector3) -> void:
	var fountain := BloodFountain.new()
	parent.add_child(fountain)
	fountain.global_position = at
	fountain.direction = dir.normalized() if dir != Vector3.ZERO else Vector3.UP
	fountain.emitting = true


func _init() -> void:
	one_shot = true
	explosiveness = 0.75
	amount = 70
	lifetime = 0.8
	spread = 18.0
	gravity = Vector3(0.0, -16.0, 0.0)
	initial_velocity_min = 4.0
	initial_velocity_max = 9.5
	scale_amount_min = 0.5
	scale_amount_max = 1.3
	color = Dummy.BLEED_COLOR
	var drop := BoxMesh.new()
	drop.size = Vector3(0.06, 0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	drop.material = material
	mesh = drop
	finished.connect(queue_free)
