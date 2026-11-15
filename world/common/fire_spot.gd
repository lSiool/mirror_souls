class_name FireSpot
extends Node3D
## Очаг пожара в деревне (§9.2): слоёный огонь без текстур — мягкая подсветка у основания, широкие
## тусклые языки сзади и узкие яркие спереди (Flame), столб дыма, искры и дрожащий свет. Слои разной
## глубины и яркости не дают огню выглядеть наклейкой рядом с рисованными моделями.
## Огонь поджигает смолу (TarPool, §6.2): очаг — в группе fire_source.

const GLOW_SHADER := preload("res://effects/fire/fire_glow.gdshader")
const SMOKE_SHADER := preload("res://effects/fire/fire_smoke.gdshader")
const FLICKER_SPEED := 9.0
const BACK_TONGUES := 3
const FRONT_TONGUES := 4
## Прозрачность задних языков: они тусклее и шире, передние — ярче и уже.
const BACK_FADE := 0.5

static var _glows := {}
static var _smoke_material: ShaderMaterial

@export var size := Vector3(1.6, 2.2, 0.6)
@export var light_energy := 2.2
@export var light_range := 8.0
## Огонь на крыше (§9.2): узел — у карниза по центру крыши, size — её ширина, высота конька и глубина.
## Пожар у каждого дома свой: языки на скатах и коньке на разной глубине, низ каждого лежит по скату
## (на крыше под 45° — наклонно, на ровной земле — ровно), огонь растёт вертикально вверх; жар сквозь
## прогары на фронтоне; очаг сдвинут к одному краю. Шире крыши пламя не идёт.
@export var roof := false
## Раскладка пожара на крыше: от числа зависят места, размер и число языков.
@export var roof_seed := 0

var _light: OmniLight3D
var _t := 0.0
## Где горит сильнее всего: там свет и искры.
var _focus := Vector3.ZERO
var _smoke_at := Vector3.ZERO
var _smoke_width := 1.0


func _ready() -> void:
	add_to_group(&"fire_source")
	_t = randf() * 10.0
	_focus = Vector3(0.0, size.y * 0.6, size.z + 0.6)
	_smoke_at = Vector3(0.0, size.y * 0.8, 0.0)
	_smoke_width = size.x
	if roof:
		_build_roof()
	else:
		_build_ground()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.position = _focus
	add_child(_light)
	add_child(_smoke())
	add_child(_embers())


func _process(delta: float) -> void:
	_t += delta * FLICKER_SPEED
	var pulse := 0.75 + 0.15 * sin(_t) + 0.1 * sin(_t * 2.7)
	_light.light_energy = light_energy * pulse


## Задевает ли огонь шар в точке (смола поджигается, если лужа касается очага).
func touches(at: Vector3, radius: float) -> bool:
	var local := at - global_position
	return absf(local.x) <= size.x * 0.5 + radius and local.y >= -radius and local.y <= size.y + radius


## Костёр и пожар на земле: свечение, тусклые широкие языки, поверх них — узкие яркие.
func _build_ground() -> void:
	_glow(Vector2(size.x * 2.0, size.y * 1.3), Vector3(0.0, size.y * 0.3, 0.1), 0.45)
	for i in BACK_TONGUES:
		var k := float(i) / float(BACK_TONGUES - 1) - 0.5
		var height := size.y * (1.0 - absf(k) * 0.8) * randf_range(0.9, 1.15)
		_tongue(Vector2(size.x * 0.75, height), Vector3(k * size.x * 0.7, 0.0, -0.12), BACK_FADE)
	for i in FRONT_TONGUES:
		var k := (float(i) + 0.5) / float(FRONT_TONGUES) - 0.5 + randf_range(-0.06, 0.06)
		var height := size.y * (1.0 - absf(k) * 0.9) * randf_range(0.55, 1.05)
		_tongue(Vector2(size.x * 0.42, height), Vector3(k * size.x * 0.85, 0.0, 0.05 * (i % 2)))


## surface — поверхность под огнём (Flame.make): по умолчанию ровная, на крыше — скат.
func _tongue(flame_size: Vector2, at: Vector3, fade := 1.0, surface := Vector3.ZERO) -> void:
	var flame := Flame.make(flame_size, &"fire", surface)
	flame.position = at
	if fade < 1.0:
		flame.fade = fade
	add_child(flame)


## Мягкое круглое свечение — подкладка под огонь и жар в прогарах.
func _glow(glow_size: Vector2, at: Vector3, strength: float, softness := 2.2) -> void:
	var quad := QuadMesh.new()
	quad.size = glow_size
	var spot := MeshInstance3D.new()
	spot.mesh = quad
	spot.material_override = _glow_material(strength, softness)
	spot.position = at
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot.set_instance_shader_parameter(&"seed", randf() * 10.0)
	add_child(spot)


static func _glow_material(strength: float, softness: float, color := Color(1.0, 0.42, 0.1)) -> ShaderMaterial:
	var key := "%s_%s_%s" % [strength, softness, color]
	if not _glows.has(key):
		var material := ShaderMaterial.new()
		material.shader = GLOW_SHADER
		material.set_shader_parameter(&"glow_color", color)
		material.set_shader_parameter(&"strength", strength)
		material.set_shader_parameter(&"softness", softness)
		_glows[key] = material
	return _glows[key]


## Пожар на крыше по зерну roof_seed.
func _build_roof() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = roof_seed
	var half := size.x * 0.5
	var face := size.z * 0.5
	# Огонь идёт с одного края, сила у каждого дома своя.
	var lean := rng.randf_range(-0.2, 0.2) * size.x
	var heat := rng.randf_range(0.75, 1.15)
	# Жар над кровлей: свет от огня ложится на крышу и конёк модели.
	_glow(Vector2(size.x * 1.5, size.y * 1.7), Vector3(lean, size.y * 0.6, face * 0.4), 0.4)
	# Языки на скатах и коньке, на разной глубине крыши; дальние тусклее. Основание утоплено под скат
	# по внешнему краю языка — в воздухе он не висит.
	for i in rng.randi_range(4, 5):
		var width := size.x * rng.randf_range(0.16, 0.32)
		var x := clampf(lean + rng.randf_range(-0.34, 0.34) * size.x, -half * 0.85 + width * 0.5, half * 0.85 - width * 0.5)
		var base := _slope(absf(x) + width * 0.5) - 0.15
		var top := _slope(absf(x)) + size.y * rng.randf_range(0.2, 0.5) * heat
		# Низ языка ложится по скату (ребро — на коньке, x = 0 крыши), а сам язык растёт вертикально вверх.
		_tongue(Vector2(width, top - base), Vector3(x, base, rng.randf_range(-0.7, 0.9) * face), rng.randf_range(0.55, 1.0),
				Vector3(-x, size.y - base, size.y / half))
	# Жар сквозь прогары фронтона: только тёплое пятно на стене, языка там нет — пламя не стоит на вертикали.
	for i in rng.randi_range(1, 2):
		var width := size.x * rng.randf_range(0.1, 0.16)
		var x := clampf(lean + rng.randf_range(-0.28, 0.28) * size.x, -half * 0.6, half * 0.6)
		_glow(Vector2(width * 2.0, width * 1.5), Vector3(x, _slope(absf(x)) * rng.randf_range(0.15, 0.5) + width * 0.3, face + 0.05), 0.5, 1.8)
	_focus = Vector3(lean, size.y * 0.9, face + 0.6)
	_smoke_at = Vector3(lean, size.y * 0.95, 0.0)
	_smoke_width = size.x * 0.7


## Высота ската над карнизом на расстоянии от конька.
func _slope(from_ridge: float) -> float:
	return size.y * maxf(1.0 - from_ridge / (size.x * 0.5), 0.0)


## Столб дыма: тёмные мягкие клубы растут, сносятся ветром и тают.
func _smoke() -> CPUParticles3D:
	if _smoke_material == null:
		_smoke_material = ShaderMaterial.new()
		_smoke_material.shader = SMOKE_SHADER
	var quad := QuadMesh.new()
	quad.material = _smoke_material
	var particles := CPUParticles3D.new()
	particles.mesh = quad
	particles.amount = clampi(roundi(_smoke_width * 3.0), 5, 12)
	particles.lifetime = 3.6
	particles.preprocess = 3.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(_smoke_width * 0.3, 0.1, 0.1)
	particles.position = _smoke_at
	particles.direction = Vector3.UP
	particles.spread = 14.0
	particles.gravity = Vector3(0.45, 0.35, 0.0)
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 1.2
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	var puff := clampf(_smoke_width * 0.55, 0.8, 2.4)
	particles.scale_amount_min = puff * 0.8
	particles.scale_amount_max = puff * 1.2
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.45))
	growth.add_point(Vector2(1.0, 1.6))
	particles.scale_amount_curve = growth
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Искры: мягкие светлые точки взлетают, краснеют и гаснут.
func _embers() -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.material = _glow_material(1.5, 1.2, Color(1.0, 0.62, 0.22))
	var particles := CPUParticles3D.new()
	particles.mesh = quad
	particles.amount = 10 if roof else clampi(roundi(size.x * 5.0), 8, 18)
	particles.lifetime = 2.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(size.x * (0.25 if roof else 0.45), 0.2, 0.2)
	particles.position = Vector3(_focus.x, size.y * 0.9, 0.0) if roof else Vector3(0.0, size.y * 0.4, 0.0)
	particles.direction = Vector3.UP
	particles.spread = 30.0
	particles.gravity = Vector3(0.6, 1.2, 0.0)
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 2.0
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.13
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.3))
	particles.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.45, 0.12, 1.0), Color(0.55, 0.08, 0.02, 0.0)])
	particles.color_ramp = ramp
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
