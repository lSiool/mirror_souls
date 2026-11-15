class_name FireSpot
extends Node3D
## Очаг пожара в деревне (§9.2): языки процедурного пламени (Flame), дрожащий свет и искры.
## Огонь поджигает смолу (TarPool, §6.2): очаг — в группе fire_source.

const EMBER_COLOR := Color(1.0, 0.55, 0.2)
const FLICKER_SPEED := 9.0
const TONGUES := 5
## Прогар на кровле: обугленное пятно и жар внутри, из него рвётся язык.
const SCORCH_COLOR := Color(0.035, 0.022, 0.018)
const GLOW_COLOR := Color(1.0, 0.36, 0.08)

static var _scorch_materials: Array[StandardMaterial3D] = []

@export var size := Vector3(1.6, 2.2, 0.6)
@export var light_energy := 2.2
@export var light_range := 8.0
## Огонь на крыше (§9.2): узел — у карниза по центру крыши, size — её ширина, высота конька и глубина.
## Пожар у каждого дома свой: языки на скатах и коньке на разной глубине, прогары на фронтоне,
## огонь сползает по карнизу; очаг сдвинут к одному краю. Шире крыши пламя не идёт.
@export var roof := false
## Раскладка пожара на крыше: от числа зависят места, размер и число языков.
@export var roof_seed := 0

var _light: OmniLight3D
var _t := 0.0
## Где горит сильнее всего: там свет и искры.
var _focus := Vector3.ZERO


func _ready() -> void:
	add_to_group(&"fire_source")
	_t = randf() * 10.0
	_focus = Vector3(0.0, size.y * 0.6, size.z + 0.6)
	if roof:
		_build_roof()
	else:
		# Языки разной высоты по ширине очага, середина выше; задние чуть глубже.
		for i in TONGUES:
			var k := float(i) / float(TONGUES - 1) - 0.5
			var height := size.y * (1.0 - absf(k) * 0.9) * randf_range(0.85, 1.1)
			_tongue(Vector2(size.x * 0.7, height), Vector3(k * size.x * 0.8, 0.0, -0.08 * (i % 2)))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.position = _focus
	add_child(_light)
	add_child(_embers())


func _process(delta: float) -> void:
	_t += delta * FLICKER_SPEED
	var pulse := 0.75 + 0.15 * sin(_t) + 0.1 * sin(_t * 2.7)
	_light.light_energy = light_energy * pulse


func _tongue(flame_size: Vector2, at: Vector3) -> void:
	var flame := Flame.make(flame_size)
	flame.position = at
	add_child(flame)


## Пожар на крыше по зерну roof_seed.
func _build_roof() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = roof_seed
	var half := size.x * 0.5
	var face := size.z * 0.5
	# Огонь идёт с одного края, сила у каждого дома своя.
	var lean := rng.randf_range(-0.2, 0.2) * size.x
	var heat := rng.randf_range(0.75, 1.15)
	# Языки на скатах и коньке, на разной глубине крыши. Основание утоплено под скат по внешнему
	# краю языка — в воздухе он не висит.
	for i in rng.randi_range(2, 3):
		var width := size.x * rng.randf_range(0.14, 0.26)
		var x := clampf(lean + rng.randf_range(-0.3, 0.3) * size.x, -half * 0.85 + width * 0.5, half * 0.85 - width * 0.5)
		var base := _slope(absf(x) + width * 0.5) - 0.1
		var top := _slope(absf(x)) + size.y * rng.randf_range(0.25, 0.65) * heat
		_tongue(Vector2(width, top - base), Vector3(x, base, rng.randf_range(-0.6, 0.8) * face))
	# Прогары на фронтоне: огонь рвётся изнутри сквозь кровлю и лижет её до ската.
	for i in rng.randi_range(1, 2):
		var width := size.x * rng.randf_range(0.1, 0.17)
		var x := clampf(lean + rng.randf_range(-0.28, 0.28) * size.x, -half * 0.6, half * 0.6)
		var room := _slope(absf(x))
		var y := room * rng.randf_range(0.12, 0.5)
		var height := minf(size.y * rng.randf_range(0.3, 0.5) * heat, room - y + size.y * 0.15)
		_scorch(Vector3(x, y + width * 0.2, face), width)
		_tongue(Vector2(width, height), Vector3(x, y, face + 0.08))
	# С горящего края огонь сползает по карнизу.
	if rng.randf() < 0.6:
		var x := (1.0 if lean >= 0.0 else -1.0) * half * rng.randf_range(0.72, 0.86)
		_tongue(Vector2(size.x * 0.1, size.y * rng.randf_range(0.2, 0.32)), Vector3(x, -0.05, face + 0.08))
	_focus = Vector3(lean, size.y * 0.9, face + 0.6)


## Высота ската над карнизом на расстоянии от конька.
func _slope(from_ridge: float) -> float:
	return size.y * maxf(1.0 - from_ridge / (size.x * 0.5), 0.0)


## Прогар: обугленное пятно на кровле и жар в его середине.
func _scorch(at: Vector3, width: float) -> void:
	if _scorch_materials.is_empty():
		for glow in [false, true]:
			var material := StandardMaterial3D.new()
			material.albedo_color = SCORCH_COLOR
			if glow:
				material.emission_enabled = true
				material.emission = GLOW_COLOR
				material.emission_energy_multiplier = 2.2
			_scorch_materials.append(material)
	for i in 2:
		var spot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 12
		mesh.rings = 6
		mesh.material = _scorch_materials[i]
		spot.mesh = mesh
		spot.scale = Vector3(width * 1.5, width * 1.1, 0.06) if i == 0 else Vector3(width * 0.8, width * 0.5, 0.09)
		spot.position = at
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spot)


## Задевает ли огонь шар в точке (смола поджигается, если лужа касается очага).
func touches(at: Vector3, radius: float) -> bool:
	var local := at - global_position
	return absf(local.x) <= size.x * 0.5 + radius and local.y >= -radius and local.y <= size.y + radius


func _embers() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var speck := BoxMesh.new()
	speck.size = Vector3(0.05, 0.05, 0.05)
	var material := StandardMaterial3D.new()
	material.albedo_color = EMBER_COLOR
	material.emission_enabled = true
	material.emission = EMBER_COLOR
	material.emission_energy_multiplier = 4.0
	speck.material = material
	particles.mesh = speck
	particles.amount = 10 if roof else 16
	particles.lifetime = 2.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(size.x * (0.25 if roof else 0.5), 0.3, 0.3)
	particles.position = Vector3(_focus.x, size.y * 0.9, 0.0) if roof else Vector3(0.0, size.y * 0.5, 0.0)
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.gravity = Vector3(0.6, 1.2, 0.0)
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 1.8
	return particles
