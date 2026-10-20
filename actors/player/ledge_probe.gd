class_name LedgeProbe
extends RefCounted
## Поиск края уступа, за который герой может зацепиться (§5).
## Край — верх твёрдого уступа перед героем; стекло для лазания и скаты не в счёт.

const WORLD_MASK := 1
## Насколько далеко перед собой герой дотягивается до края.
const REACH := 0.3

## Высота края над ногами.
var height := 0.0
## Где висеть (ноги) и куда встать наверху.
var hang := Vector3.ZERO
var stand := Vector3.ZERO
## Висеть негде (край низкий или под ним тесно) — сразу подтягиваться.
var vault := false


## Край перед героем в сторону dir или null.
static func find(body: CharacterBody3D, shape: CollisionShape3D, dir: float,
		stats: PlayerStats) -> LedgeProbe:
	var space := body.get_world_3d().direct_space_state
	var exclude: Array[RID] = [body.get_rid()]
	var radius := (shape.shape as CapsuleShape3D).radius
	var feet := body.global_position
	# Верх уступа: луч вниз чуть дальше края — от высоты рук до пояса.
	var probe_x := feet.x + dir * (radius + REACH)
	var top_hit := _ray(space, Vector3(probe_x, feet.y + stats.ledge_hang_max + 0.05, 0.0),
		Vector3(probe_x, feet.y + stats.ledge_vault_min, 0.0), exclude)
	if top_hit.is_empty() or top_hit.normal.y < 0.7 or _special(top_hit.collider):
		return null
	var top: float = top_hit.position.y
	# Стена уступа: луч от героя вбок чуть ниже края.
	var wall_y := top - 0.08
	var wall_hit := _ray(space, Vector3(feet.x, wall_y, 0.0), Vector3(probe_x, wall_y, 0.0), exclude)
	if wall_hit.is_empty() or absf(wall_hit.normal.y) > 0.3 or _special(wall_hit.collider):
		return null
	var wall_x: float = wall_hit.position.x
	var ledge := LedgeProbe.new()
	ledge.height = top - feet.y
	ledge.hang = Vector3(wall_x - dir * (radius + 0.02), top - stats.ledge_hang_depth, 0.0)
	ledge.stand = Vector3(wall_x + dir * (radius + 0.1), top + 0.02, 0.0)
	# Наверху должно быть место, чтобы встать.
	if _blocked(space, shape, ledge.stand, exclude):
		return null
	ledge.vault = ledge.height < stats.ledge_hang_min or _blocked(space, shape, ledge.hang, exclude)
	return ledge


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Array[RID]) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude))


## Стекло для лазания и скаты — у них свои правила, за их край не цепляемся.
static func _special(collider: Object) -> bool:
	var node := collider as Node
	return node != null and (node.is_in_group("glass_climb") or node.is_in_group("glass_slide"))


static func _blocked(space: PhysicsDirectSpaceState3D, shape: CollisionShape3D, feet: Vector3,
		exclude: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, feet + shape.position)
	query.collision_mask = WORLD_MASK
	query.exclude = exclude
	return not space.intersect_shape(query, 1).is_empty()
