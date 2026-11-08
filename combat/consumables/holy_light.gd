class_name HolyLight
extends FlaskZone
## Свет святой склянки (§6.2): после вспышки тёплый свет остаётся там, где она разбилась,
## и освещает тёмную комнату zone_time секунд, медленно угасая. Никого не задевает —
## урон и кресты над нежитью — во вспышке (Thrown._burst).

const COLOR := Color(1.0, 0.9, 0.65)
const ENERGY := 2.6
const RANGE := 9.0

var _light: OmniLight3D
var _motes: CPUParticles3D


func _settle(at: Vector3) -> bool:
	global_position = at + Vector3(0.0, 0.4, 0.0)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = RANGE
	_light.light_energy = ENERGY
	_light.position = Vector3(0.0, 0.6, 0.8)
	add_child(_light)
	_motes = CPUParticles3D.new()
	var mote := SphereMesh.new()
	mote.radius = 0.025
	mote.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR
	mote.material = material
	_motes.mesh = mote
	_motes.amount = 20
	_motes.lifetime = 2.5
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 1.0
	_motes.gravity = Vector3(0.0, 0.25, 0.0)
	_motes.initial_velocity_max = 0.2
	add_child(_motes)
	return true


func _fade(k: float) -> void:
	# Угасает не за секунду, а всю вторую половину жизни.
	var tail := clampf((life - _age) / (life * 0.5), 0.0, 1.0)
	_light.light_energy = ENERGY * tail * (0.95 + 0.05 * sin(_age * 3.0))
	_motes.emitting = k > 0.5
