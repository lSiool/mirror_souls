class_name FirePool
extends FlaskZone
## Огненная лужа (§6.2): горящее масло растекается от точки удара по платформе — до края,
## стены или zone_radius в каждую сторону — и горит. Кто внутри — загорается (Statuses.BURNING),
## и герой тоже. Касается смолы — смола взрывается.

const SPREAD_TIME := 0.6
const TONGUE_STEP := 0.45
const HEIGHT := 1.6

var floor_y := 0.0
var left := 0.0
var right := 0.0
var _left_max := 0.0
var _right_max := 0.0
var _tongues: Array[Flame] = []
var _light: OmniLight3D
var _oil: MeshInstance3D


func _settle(at: Vector3) -> bool:
	floor_y = floor_at(at.x, at.y + 0.4)
	if is_nan(floor_y):
		return false
	global_position = Vector3(at.x, floor_y, 0.0)
	_left_max = spread_to(at.x, floor_y, -1.0, data.zone_radius)
	_right_max = spread_to(at.x, floor_y, 1.0, data.zone_radius)
	_oil = FlaskZone.puddle(1.0, Color(0.12, 0.05, 0.02), 0.2)
	add_child(_oil)
	# Языки пламени по всей будущей луже; загораются, когда огонь до них дотёк.
	var x := -_left_max
	while x <= _right_max + 0.01:
		var flame := Flame.make(Vector2(1.15, HEIGHT * randf_range(0.65, 1.0)))
		flame.position = Vector3(x, 0.0, randf_range(-0.15, 0.15))
		flame.fade = 0.0
		add_child(flame)
		_tongues.append(flame)
		x += TONGUE_STEP
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.omni_range = 6.0
	_light.position = Vector3(0.0, 1.0, 0.8)
	add_child(_light)
	return true


func covers(point: Vector3) -> bool:
	var dx := point.x - global_position.x
	return dx >= -left - 0.2 and dx <= right + 0.2 and point.y >= floor_y - 0.4 and point.y <= floor_y + HEIGHT


func _touch_enemy(enemy: Dummy) -> void:
	enemy.statuses.apply(Statuses.BURNING, data.status_time)


func _touch_player(player: Player) -> void:
	player.statuses.apply(Statuses.BURNING, 1.0)


func _on_tick() -> void:
	for node in get_tree().get_nodes_in_group(&"tar"):
		var tar := node as TarPool
		if tar and tar.overlaps(global_position.x - left, global_position.x + right, floor_y):
			tar.ignite()


func _fade(k: float) -> void:
	var spread := clampf(_age / SPREAD_TIME, 0.0, 1.0)
	left = _left_max * spread
	right = _right_max * spread
	_oil.scale.x = maxf(left + right, 0.05)
	_oil.position.x = (right - left) * 0.5
	for flame in _tongues:
		var lit := 1.0 if flame.position.x >= -left - 0.05 and flame.position.x <= right + 0.05 else 0.0
		flame.fade = lit * k
	_light.light_energy = (2.0 + 0.4 * sin(_age * 17.0) + 0.3 * sin(_age * 7.3)) * k * maxf(spread, 0.3)
