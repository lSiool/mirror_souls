class_name FireSpot
extends Node3D
## Очаг пожара в деревне (§9.2): языки пламени, дрожащий свет и искры. Заглушка до настоящего огня.

const FLAME_COLOR := Color(1.0, 0.32, 0.06)
const EMBER_COLOR := Color(1.0, 0.55, 0.2)
const FLICKER_SPEED := 9.0

@export var size := Vector3(1.6, 2.2, 0.6)
@export var light_energy := 2.2
@export var light_range := 8.0

var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = FLAME_COLOR
	flame_material.emission_enabled = true
	flame_material.emission = FLAME_COLOR
	flame_material.emission_energy_multiplier = 1.8
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = size.x * (0.3 - 0.05 * i)
		cone.height = size.y * (1.0 - 0.2 * i)
		cone.radial_segments = 6
		cone.rings = 1
		cone.material = flame_material
		var mesh := MeshInstance3D.new()
		mesh.mesh = cone
		mesh.position = Vector3(size.x * 0.28 * (i - 1), cone.height * 0.5, 0.0)
		add_child(mesh)
		_flames.append(mesh)
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
	for i in _flames.size():
		var flame := _flames[i]
		flame.scale.y = 0.85 + 0.2 * sin(_t * 1.3 + i * 1.9)
		flame.position.y = (flame.mesh as CylinderMesh).height * 0.5 * flame.scale.y


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
