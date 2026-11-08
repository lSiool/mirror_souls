class_name FlaskZone
extends Node3D
## То, что склянка оставляет после себя (§6.2): лужа или облако, которое живёт zone_time секунд
## и каждые четверть секунды задевает тех, кто внутри, — врагов и героя (как в Souls).
## Наследники: FirePool, PoisonCloud, AcidPool, TarPool, HolyLight. Зона — данные склянки
## (ConsumableData), здесь — общее: время жизни, угасание, поиск пола под точкой удара.

const TICK := 0.25
## Последняя секунда — угасание.
const FADE_TIME := 1.0
const WORLD_MASK := 1
## Шаг, которым лужа ощупывает платформу, и допустимая ступенька.
const PROBE_STEP := 0.25
const PROBE_STEP_UP := 0.25

var data: ConsumableData
var life := 5.0
var _age := 0.0
var _tick := 0.0


## Создать зону склянки в точке разбивания. Лужи ищут пол под точкой; нет пола — лужи нет.
static func spawn(parent: Node, at: Vector3, item: ConsumableData) -> FlaskZone:
	var zone: FlaskZone
	match item.zone:
		ConsumableData.Zone.FIRE: zone = FirePool.new()
		ConsumableData.Zone.POISON: zone = PoisonCloud.new()
		ConsumableData.Zone.ACID: zone = AcidPool.new()
		ConsumableData.Zone.TAR: zone = TarPool.new()
		ConsumableData.Zone.HOLY: zone = HolyLight.new()
		_: return null
	zone.data = item
	zone.life = item.zone_time
	parent.add_child(zone)
	zone.global_position = at
	if not zone._settle(at):
		zone.queue_free()
		return null
	return zone


## Встать на место: лужа — на пол, облако — где разбилось. false — зоне здесь не быть.
func _settle(_at: Vector3) -> bool:
	return true


## Внутри ли точка (ноги врага или героя).
func covers(_point: Vector3) -> bool:
	return false


func _touch_enemy(_enemy: Dummy) -> void:
	pass


func _touch_player(_player: Player) -> void:
	pass


## Вид зоны при угасании: k от 1 до 0.
func _fade(_k: float) -> void:
	pass


## Каждый тик — помимо тех, кто внутри (поджечь смолу и т. п.).
func _on_tick() -> void:
	pass


func fade_k() -> float:
	return clampf((life - _age) / FADE_TIME, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	_fade(fade_k())
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Dummy
		if enemy and enemy.state != Dummy.State.DEAD and covers(enemy.global_position):
			_touch_enemy(enemy)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.is_dead() and covers(player.global_position):
		_touch_player(player)
	_on_tick()


## Пол под точкой: высота или NAN, если пола нет в пределах depth.
func floor_at(x: float, from_y: float, depth := 6.0) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, 0.0), Vector3(x, from_y - depth, 0.0), WORLD_MASK)
	var hit := space.intersect_ray(query)
	return (hit.position as Vector3).y if not hit.is_empty() else NAN


## Докуда лужа растечётся по платформе от x в сторону dir: край, стена или max_len.
func spread_to(x: float, floor_y: float, dir: float, max_len: float) -> float:
	var space := get_world_3d().direct_space_state
	var wall := PhysicsRayQueryParameters3D.create(Vector3(x, floor_y + 0.3, 0.0), Vector3(x + dir * max_len, floor_y + 0.3, 0.0), WORLD_MASK)
	var hit := space.intersect_ray(wall)
	var limit := max_len if hit.is_empty() else absf((hit.position as Vector3).x - x) - 0.05
	var reach := 0.0
	while reach + PROBE_STEP <= limit:
		var y := floor_at(x + dir * (reach + PROBE_STEP), floor_y + PROBE_STEP_UP)
		if is_nan(y) or absf(y - floor_y) > PROBE_STEP_UP:
			break
		reach += PROBE_STEP
	return reach


## Плоская лужа-заглушка на полу: блестящая плёнка шириной width.
static func puddle(width: float, color: Color, roughness := 0.1) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.04, 1.2)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.2
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = material
	mesh.mesh = box
	mesh.position.y = 0.03
	return mesh
