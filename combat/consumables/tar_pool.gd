class_name TarPool
extends FlaskZone
## Клейкая смола на полу (§6.2): лежит zone_time секунд, урона нет. Враг, вошедший в неё, снова
## объят смолой (Statuses.TAR, status_time), летуны не прилипают; герой вязнет, пока стоит в ней.
## Огонь — костёр, огненная лужа, горящий враг, огненная стрела — поджигает смолу: взрыв.

const COLOR := Color(0.03, 0.025, 0.02)
## Сколько держится смола на герое, пока он в луже (обновляется каждый тик).
const PLAYER_TIME := 0.5

var floor_y := 0.0
var half := 0.0
var _film: MeshInstance3D
var _ignited := false


func _settle(at: Vector3) -> bool:
	floor_y = floor_at(at.x, at.y + 0.4)
	if is_nan(floor_y):
		return false
	add_to_group(&"tar")
	global_position = Vector3(at.x, floor_y, 0.0)
	var left := spread_to(at.x, floor_y, -1.0, data.zone_radius)
	var right := spread_to(at.x, floor_y, 1.0, data.zone_radius)
	half = (left + right) * 0.5
	global_position.x += (right - left) * 0.5
	_film = FlaskZone.puddle(maxf(left + right, 0.3), COLOR, 0.04)
	((_film.mesh as BoxMesh).material as StandardMaterial3D).metallic = 0.5
	add_child(_film)
	return true


func covers(point: Vector3) -> bool:
	return absf(point.x - global_position.x) <= half + 0.15 and point.y >= floor_y - 0.4 and point.y <= floor_y + 0.5


## Перекрывается ли лужа с отрезком пола [x0, x1] на той же высоте.
func overlaps(x0: float, x1: float, y: float) -> bool:
	return absf(y - floor_y) < 0.5 and x1 >= global_position.x - half and x0 <= global_position.x + half


func _touch_enemy(enemy: Dummy) -> void:
	if enemy is Bat:
		return
	if enemy.statuses.has(Statuses.BURNING):
		ignite()
		return
	enemy.statuses.apply(Statuses.TAR, data.status_time)


func _touch_player(player: Player) -> void:
	player.statuses.apply(Statuses.TAR, PLAYER_TIME)


## Огонь у костров в мире (FireSpot).
func _on_tick() -> void:
	for node in get_tree().get_nodes_in_group(&"fire_source"):
		if node.has_method("touches") and node.touches(global_position, half):
			ignite()
			return


## Смола вспыхнула: взрыв во всю лужу, смолы больше нет.
func ignite() -> void:
	if _ignited:
		return
	_ignited = true
	TarBlast.explode.call_deferred(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), maxf(TarBlast.RADIUS, half + 0.8))
	queue_free()


func _fade(k: float) -> void:
	_film.scale.y = k
	_film.visible = k > 0.02
