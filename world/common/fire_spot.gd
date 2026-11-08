class_name FireSpot
extends Node3D
## Очаг пожара в деревне (§9.2): языки процедурного пламени (Flame), дрожащий свет и искры.
## Огонь поджигает смолу (TarPool, §6.2): очаг — в группе fire_source.

const EMBER_COLOR := Color(1.0, 0.55, 0.2)
const FLICKER_SPEED := 9.0
const TONGUES := 5

@export var size := Vector3(1.6, 2.2, 0.6)
@export var light_energy := 2.2
@export var light_range := 8.0

var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"fire_source")
	_t = randf() * 10.0
	# Языки разной высоты по ширине очага, середина выше; задние чуть глубже.
	for i in TONGUES:
		var k := float(i) / float(TONGUES - 1) - 0.5
		var height := size.y * (1.0 - absf(k) * 0.9) * randf_range(0.85, 1.1)
		var flame := Flame.make(Vector2(size.x * 0.7, height))
		flame.position = Vector3(k * size.x * 0.8, 0.0, -0.08 * (i % 2))
		add_child(flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.position = Vector3(0.0, size.y * 0.6, size.z + 0.6)
	add_child(_light)
	add_child(_embers())


func _process(delta: float) -> void:
	_t += delta * FLICKER_SPEED
	var pulse := 0.75 + 0.15 * sin(_t) + 0.1 * sin(_t * 2.7)
	_light.light_energy = light_energy * pulse


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
	particles.amount = 16
	particles.lifetime = 2.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(size.x * 0.5, 0.3, 0.3)
	particles.position.y = size.y * 0.5
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.gravity = Vector3(0.6, 1.2, 0.0)
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 1.8
	return particles
