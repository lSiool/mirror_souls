class_name PoisonCloud
extends FlaskZone
## Ядовитое облако (§6.2): клубится, где разбилась склянка, медленно поднимается и тает.
## Кто внутри — отравлен (Statuses.POISON), яд держится status_time после выхода. Героя тоже травит.

const RISE_SPEED := 0.12
const COLOR := Color(0.55, 0.28, 0.7)

var _puffs: CPUParticles3D


func _settle(at: Vector3) -> bool:
	global_position = Vector3(at.x, at.y + 0.3, 0.0)
	var r := data.zone_radius
	_puffs = CPUParticles3D.new()
	var puff := QuadMesh.new()
	puff.size = Vector2(0.9, 0.9)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	puff.material = material
	_puffs.mesh = puff
	_puffs.amount = 56
	_puffs.lifetime = 2.2
	_puffs.preprocess = 1.0
	_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puffs.emission_sphere_radius = r * 0.7
	_puffs.direction = Vector3.UP
	_puffs.spread = 180.0
	_puffs.gravity = Vector3(0.0, 0.15, 0.0)
	_puffs.initial_velocity_min = 0.1
	_puffs.initial_velocity_max = 0.4
	_puffs.scale_amount_min = 1.0
	_puffs.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(COLOR, 0.0), Color(COLOR, 0.42),
		Color(COLOR.darkened(0.3), 0.32), Color(COLOR.darkened(0.5), 0.0)])
	_puffs.color_ramp = ramp
	add_child(_puffs)
	return true


## Мягкое круглое пятно для клубов: без него частица — квадрат.
static func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func covers(point: Vector3) -> bool:
	# Ноги или грудь — в облаке.
	var chest := point + Vector3(0.0, 0.9, 0.0)
	return chest.distance_to(global_position) <= data.zone_radius or point.distance_to(global_position) <= data.zone_radius * 0.8


func _touch_enemy(enemy: Dummy) -> void:
	enemy.statuses.apply(Statuses.POISON, data.status_time)


func _touch_player(player: Player) -> void:
	player.statuses.apply(Statuses.POISON, data.status_time)


func _fade(k: float) -> void:
	global_position.y += RISE_SPEED * get_physics_process_delta_time()
	_puffs.emitting = k > 0.6
