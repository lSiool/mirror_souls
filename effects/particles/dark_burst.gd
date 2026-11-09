class_name DarkBurst
extends Node3D
## Тёмный взрыв превращения вампира (§6.3, 2026-11-09): багровая вспышка, клубы тьмы, стая мелких
## летучих мышей во все стороны и кольцо по земле. Скрывает миг, когда человек становится мышью
## и обратно. Одноразовый: сам исчезает. power — размер (1 — удар пике, меньше — посадка).

const SMOKE := Color(0.06, 0.02, 0.05)
const GLOW := Color(0.75, 0.06, 0.14)
const LIFE := 1.4


static func spawn(parent: Node, at: Vector3, power := 1.0) -> DarkBurst:
	var burst := DarkBurst.new()
	parent.add_child(burst)
	burst.global_position = at
	burst._make(power)
	return burst


func _make(power: float) -> void:
	# Вспышка: свет гаснет за треть секунды.
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 7.0 * power
	light.omni_range = 7.0 * power
	light.position.y = 1.0
	add_child(light)
	var fade := light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.35)
	# Клубы тьмы: крупные, растут и тают, расползаются в стороны и вверх.
	var smoke := _particles(int(36 * power), _puff_mesh(), 0.9)
	smoke.position.y = 0.9
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.8 * power
	smoke.initial_velocity_min = 2.0 * power
	smoke.initial_velocity_max = 5.5 * power
	smoke.damping_min = 5.0
	smoke.damping_max = 7.0
	smoke.gravity = Vector3(0.0, 0.8, 0.0)
	smoke.scale_amount_min = 1.6 * power
	smoke.scale_amount_max = 2.8 * power
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(0.3, 1.0))
	grow.add_point(Vector2(1.0, 1.3))
	smoke.scale_amount_curve = grow
	smoke.color_ramp = _ramp(Color(GLOW, 0.95), Color(SMOKE, 0.9), Color(SMOKE, 0.0))
	# Стая мышей: разлетается, хлопая (кувыркаясь), вверх и в стороны.
	var bats := _particles(int(28 * power), _bat_mesh(), 1.3)
	bats.position.y = 1.0
	bats.direction = Vector3.UP
	bats.spread = 75.0
	bats.initial_velocity_min = 5.0
	bats.initial_velocity_max = 10.0
	bats.damping_min = 2.0
	bats.damping_max = 4.0
	bats.gravity = Vector3(0.0, 1.5, 0.0)
	bats.angular_velocity_min = -600.0
	bats.angular_velocity_max = 600.0
	bats.scale_amount_min = 0.7
	bats.scale_amount_max = 1.3
	bats.color_ramp = _ramp(Color(0.05, 0.02, 0.03, 1.0), Color(0.05, 0.02, 0.03, 1.0), Color(0.05, 0.02, 0.03, 0.0))
	# Искры-угольки: тёмно-красные.
	HitSpark.spawn(self, global_position + Vector3(0.0, 0.3, 0.0), GLOW, int(30 * power))
	_ring(power)
	var end := create_tween()
	end.tween_interval(LIFE + 0.3)
	end.tween_callback(queue_free)


func _particles(amount: int, mesh: Mesh, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 4)
	p.mesh = mesh
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	add_child(p)
	p.emitting = true
	return p


func _ramp(a: Color, b: Color, c: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, a)
	ramp.set_color(1, c)
	ramp.add_point(0.25, b)
	return ramp


## Клуб дыма — мягкий шар без света: тьма, а не туман.
func _puff_mesh() -> Mesh:
	var puff := SphereMesh.new()
	puff.radius = 0.35
	puff.height = 0.7
	puff.radial_segments = 8
	puff.rings = 4
	puff.material = _particle_material()
	return puff


## Силуэт летучей мыши: тело и два зубчатых крыла, всегда лицом к камере.
func _bat_mesh() -> Mesh:
	var outline := PackedVector2Array([
		Vector2(0.0, 0.06), Vector2(0.05, 0.03), Vector2(0.2, 0.09), Vector2(0.17, 0.0),
		Vector2(0.12, -0.02), Vector2(0.08, -0.05), Vector2(0.03, -0.04), Vector2(0.0, -0.07),
	])
	var points := PackedVector2Array()
	for p in outline:
		points.append(p)
	for i in range(outline.size() - 2, 0, -1):
		points.append(Vector2(-outline[i].x, outline[i].y))
	var vertices := PackedVector3Array()
	for i in Geometry2D.triangulate_polygon(points):
		vertices.append(Vector3(points[i].x, points[i].y, 0.0) * 1.6)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _particle_material()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


func _particle_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	return material


## Кольцо по земле: быстро растёт и гаснет.
func _ring(power: float) -> void:
	var material := _particle_material()
	material.vertex_color_use_as_albedo = false
	material.albedo_color = Color(GLOW, 0.7)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.material = material
	ring.mesh = torus
	ring.position.y = 0.05
	ring.scale = Vector3(0.3, 0.3, 0.3)
	add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(4.0 * power, 1.0, 4.0 * power), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
