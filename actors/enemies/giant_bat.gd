class_name GiantBat
extends Node3D
## Огромная летучая мышь — вторая форма вампира (§6.3, 2026-11-09; образ — «Ван Хельсинг», арт
## автора позже). Graybox из примитивов: тело, голова с ушами, красные глаза, клыки, перепончатые
## крылья на пальцах — размах около 4.5 м. Только показывает: где она и что бьёт — у Vampire.
##
## Смотрит в камеру: крылья раскрыты поперёк кадра — силуэт читается издали. В полёте тело
## клонится по скорости (голова вперёд), крылья машут; в замахе пикирования глаза разгораются.

## Где центр тела над началом узла: сюда Vampire ставит середину мыши.
const CENTER := 0.9
## Перепонка крыла (правое; левое — зеркально) в плоскости крыла: плечо → запястье → пальцы.
const MEMBRANE := [
	Vector2(0.0, 0.0), Vector2(1.0, 0.35), Vector2(2.15, 0.55), Vector2(1.8, 0.05),
	Vector2(2.05, -0.35), Vector2(1.45, -0.45), Vector2(1.4, -0.95), Vector2(0.75, -0.7),
	Vector2(0.1, -0.65),
]
## Кости крыла: плечо–запястье и три пальца от запястья.
const FINGERS := [[Vector2(0.0, 0.0), Vector2(1.0, 0.35)], [Vector2(1.0, 0.35), Vector2(2.15, 0.55)],
	[Vector2(1.0, 0.35), Vector2(2.05, -0.35)], [Vector2(1.0, 0.35), Vector2(1.4, -0.95)]]
const FLAP_SPEED := 9.0

## Насколько разгорелись глаза (0…1) и машет ли (1 — во всю силу, 0 — крылья раскинуты, планирует).
var eyes_flare := 0.0
var flap := 1.0
var body_material: StandardMaterial3D

var _wings: Array[Node3D] = []
var _eye_material: StandardMaterial3D
var _eyes: Array[MeshInstance3D] = []
var _body: Node3D
var _time := 0.0


static func build(parent: Node3D) -> GiantBat:
	var bat := GiantBat.new()
	bat.name = &"GiantBat"
	parent.add_child(bat)
	bat._make()
	return bat


func _make() -> void:
	body_material = _flat(Color(0.13, 0.09, 0.1))
	body_material.emission_enabled = true
	body_material.emission = Color.BLACK
	var membrane := _flat(Color(0.2, 0.08, 0.1))
	membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bone := _flat(Color(0.08, 0.05, 0.06))
	_eye_material = _flat(Color(1.0, 0.1, 0.06))
	_eye_material.emission_enabled = true
	_eye_material.emission = Color(1.0, 0.08, 0.04)
	_eye_material.emission_energy_multiplier = 4.0
	_body = Node3D.new()
	_body.position.y = CENTER
	add_child(_body)
	# Туловище, грудь посветлее, голова с мордой, ушами и клыками.
	_body.add_child(_part(CapsuleMesh, Vector3(0.36, 1.3, 0.36), Vector3(0.0, -0.05, 0.0), body_material))
	_body.add_child(_part(SphereMesh, Vector3(0.5, 0.6, 0.3), Vector3(0.0, 0.15, 0.14), _flat(Color(0.24, 0.17, 0.16))))
	var head := Node3D.new()
	head.position = Vector3(0.0, 0.78, 0.05)
	_body.add_child(head)
	head.add_child(_part(SphereMesh, Vector3(0.56, 0.5, 0.5), Vector3.ZERO, body_material))
	head.add_child(_part(BoxMesh, Vector3(0.2, 0.16, 0.22), Vector3(0.0, -0.07, 0.25), body_material))
	for x: float in [-1.0, 1.0]:
		head.add_child(_part(PrismMesh, Vector3(0.2, 0.42, 0.06), Vector3(x * 0.17, 0.33, 0.0), body_material, Vector3(0.0, 0.0, -x * 0.3)))
		var eye := _part(SphereMesh, Vector3(0.08, 0.06, 0.05), Vector3(x * 0.1, 0.05, 0.23), _eye_material)
		head.add_child(eye)
		_eyes.append(eye)
		head.add_child(_part(PrismMesh, Vector3(0.04, 0.09, 0.03), Vector3(x * 0.05, -0.19, 0.33), _flat(Color(0.85, 0.82, 0.75)), Vector3(PI, 0.0, 0.0)))
	# Лапы-когти внизу.
	for x: float in [-1.0, 1.0]:
		_body.add_child(_part(BoxMesh, Vector3(0.07, 0.35, 0.07), Vector3(x * 0.13, -0.8, 0.0), bone, Vector3(0.0, 0.0, x * 0.25)))
	for side: float in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.22, 0.32, 0.0)
		_body.add_child(pivot)
		var points := PackedVector2Array()
		for p: Vector2 in MEMBRANE:
			points.append(Vector2(p.x * side, p.y))
		var indices := Geometry2D.triangulate_polygon(points)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in indices:
			vertices.append(Vector3(points[i].x, points[i].y, -0.02))
			normals.append(Vector3.BACK)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var skin := MeshInstance3D.new()
		skin.mesh = mesh
		skin.material_override = membrane
		pivot.add_child(skin)
		for seg: Array in FINGERS:
			var a: Vector2 = seg[0] * Vector2(side, 1.0)
			var b: Vector2 = seg[1] * Vector2(side, 1.0)
			var length := a.distance_to(b)
			var rod := _part(BoxMesh, Vector3(length, 0.05, 0.05), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0.0), bone)
			rod.rotation.z = (b - a).angle()
			pivot.add_child(rod)
		_wings.append(pivot)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# Взмах: кончики крыльев вверх-вниз в кадре и к камере — от камеры.
	var beat := sin(_time * FLAP_SPEED) * flap
	for i in _wings.size():
		var side := 1.0 if i == 0 else -1.0
		_wings[i].rotation = Vector3(0.0, side * (0.15 + beat * 0.45), side * (beat * 0.5 + 0.08 * (1.0 - flap)))
	_body.position.y = CENTER - beat * 0.08
	_eye_material.emission_energy_multiplier = 4.0 + eyes_flare * 14.0
	for eye in _eyes:
		eye.scale = Vector3.ONE * (1.0 + eyes_flare)


## Тело клонится по полёту: голова — в сторону скорости (наполовину), вертикально — висит.
func steer(velocity: Vector3, delta: float) -> void:
	var tilt := 0.0
	if velocity.length() > 1.0:
		# Крылья остаются поперёк кадра: наклон умеренный, силуэт не уходит в ребро.
		tilt = clampf(-velocity.x * 0.04 , -0.5, 0.5)
	rotation.z = lerp_angle(rotation.z, tilt, 1.0 - exp(-8.0 * delta))
	rotation.y = lerp_angle(rotation.y, clampf(velocity.x * 0.02, -0.25, 0.25), 1.0 - exp(-6.0 * delta))
	# Пикирует вниз — клонится головой к камере, набирает высоту — откидывается.
	rotation.x = lerp_angle(rotation.x, clampf(-velocity.y * 0.06, -0.5, 0.5), 1.0 - exp(-6.0 * delta))


## Свечение тела — как у врага: красное в замахе, белое от удара (берётся из материала Dummy).
func glow(emission: Color, energy: float) -> void:
	body_material.emission = emission
	body_material.emission_energy_multiplier = energy


func _part(kind: Variant, size: Vector3, at: Vector3, material: Material, tilt := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh: PrimitiveMesh = kind.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x * 0.5
		(mesh as SphereMesh).height = size.y
	elif mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = size.x
		(mesh as CapsuleMesh).height = size.y
	elif mesh is PrismMesh:
		(mesh as PrismMesh).size = size
	mesh.material = material
	node.mesh = mesh
	node.position = at
	node.rotation = tilt
	if mesh is SphereMesh and size.z != size.x:
		node.scale.z = size.z / size.x
	return node


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
