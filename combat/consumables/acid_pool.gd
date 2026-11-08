class_name AcidPool
extends FlaskZone
## Кислотная лужица (§6.2): шипит пару секунд там, где разбилась склянка. Кто наступил —
## «разъеден» (Statuses.CORRODED): бьют больнее, стойкость сбивается легче. Героя тоже разъедает.

const COLOR := Color(0.55, 0.9, 0.12)

var floor_y := 0.0
var half := 0.0
var _film: MeshInstance3D
var _hiss: CPUParticles3D


func _settle(at: Vector3) -> bool:
	floor_y = floor_at(at.x, at.y + 0.4)
	if is_nan(floor_y):
		return false
	global_position = Vector3(at.x, floor_y, 0.0)
	var left := spread_to(at.x, floor_y, -1.0, data.zone_radius)
	var right := spread_to(at.x, floor_y, 1.0, data.zone_radius)
	half = (left + right) * 0.5
	global_position.x += (right - left) * 0.5
	_film = FlaskZone.puddle(maxf(left + right, 0.3), Color(COLOR, 0.75), 0.05)
	var material := (_film.mesh as BoxMesh).material as StandardMaterial3D
	material.emission_enabled = true
	material.emission = COLOR
	material.emission_energy_multiplier = 0.6
	add_child(_film)
	_hiss = CPUParticles3D.new()
	var speck := SphereMesh.new()
	speck.radius = 0.03
	speck.height = 0.06
	var speck_material := StandardMaterial3D.new()
	speck_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	speck_material.albedo_color = COLOR
	speck.material = speck_material
	_hiss.mesh = speck
	_hiss.amount = 24
	_hiss.lifetime = 0.6
	_hiss.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_hiss.emission_box_extents = Vector3(maxf(half, 0.15), 0.02, 0.4)
	_hiss.direction = Vector3.UP
	_hiss.spread = 20.0
	_hiss.initial_velocity_min = 0.4
	_hiss.initial_velocity_max = 1.2
	_hiss.gravity = Vector3(0.0, -2.0, 0.0)
	add_child(_hiss)
	return true


func covers(point: Vector3) -> bool:
	return absf(point.x - global_position.x) <= half + 0.2 and point.y >= floor_y - 0.4 and point.y <= floor_y + 0.6


func _touch_enemy(enemy: Dummy) -> void:
	enemy.statuses.apply(Statuses.CORRODED, data.status_time)


func _touch_player(player: Player) -> void:
	player.statuses.apply(Statuses.CORRODED, data.status_time * 0.5)


func _fade(k: float) -> void:
	((_film.mesh as BoxMesh).material as StandardMaterial3D).albedo_color.a = 0.75 * k
	_hiss.emitting = k > 0.3
