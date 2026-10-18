class_name HitSpark
extends CPUParticles3D
## Одноразовая вспышка искр/осколков в точке удара.


static func spawn(parent: Node, at: Vector3, color: Color, amount := 14) -> void:
	var spark := HitSpark.new()
	spark.amount = amount
	parent.add_child(spark)
	spark.global_position = at
	spark.color = color
	spark.emitting = true


func _init() -> void:
	one_shot = true
	explosiveness = 1.0
	lifetime = 0.35
	direction = Vector3.UP
	spread = 180.0
	gravity = Vector3(0, -18, 0)
	initial_velocity_min = 4.0
	initial_velocity_max = 9.0
	scale_amount_min = 0.6
	scale_amount_max = 1.0
	var quad := BoxMesh.new()
	quad.size = Vector3(0.07, 0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	mesh = quad
	finished.connect(queue_free)
