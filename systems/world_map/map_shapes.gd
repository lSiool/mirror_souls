class_name MapShapes
extends Resource
## Настоящая форма комнат для карты мира (§8.13): твёрдое (пол, уступы, стены — проекция на плоскость кадра),
## стекло, лестницы, двери и осколки — в метрах комнаты. Снимается с самих комнат инструментом
## `tools/world_map/build_map.tscn` (запускать после правки комнат); карта рисует по нему, комнаты не грузит.
## По образцу карт Mandragora и Vigil: комната — её силуэт, пол и уступы читаются линиями.

const PATH := "res://systems/world_map/map_shapes.tres"
## Запас над самым высоким полом и под самым низким, м.
const HEADROOM := 5.0
const FOOTROOM := 1.5

## id комнаты → {left, right, bottom, top (м), solids, glass (Array[PackedVector2Array]),
## ladders (Array[Vector3]: x, низ, верх), doors (Array: [Vector2, id комнаты]), shards ({путь: Vector2})}.
@export var rooms := {}

static var _loaded: MapShapes


static func get_shapes() -> MapShapes:
	if _loaded == null:
		_loaded = load(PATH) as MapShapes if ResourceLoader.exists(PATH) else MapShapes.new()
	return _loaded


## Форма комнаты, уже стоящей в дереве (стекло и рушащиеся куски строят коллизию в _ready).
static func extract(room: Room) -> Dictionary:
	var left := room.center_x - room.width * 0.5
	var right := room.center_x + room.width * 0.5
	var to_room := room.global_transform.affine_inverse()
	var solids: Array[PackedVector2Array] = []
	var glass: Array[PackedVector2Array] = []
	var ladders: Array[Vector3] = []
	var doors: Array = []
	var shards := {}
	for node in _descendants(room):
		var local := to_room * (node as Node3D).global_transform if node is Node3D else Transform3D()
		if node is CSGBox3D and (node as CSGBox3D).use_collision:
			solids.append(_hull(local, (node as CSGBox3D).size))
		elif node is CollisionShape3D and (node as CollisionShape3D).shape is BoxShape3D and not (node as CollisionShape3D).disabled:
			var body := node.get_parent()
			if not body is StaticBody3D or body.name in [&"WallLeft", &"WallRight"]:
				continue
			var size := ((node as CollisionShape3D).shape as BoxShape3D).size
			if body is GlassSurface:
				glass.append(_hull(local, size))
			elif body is Collapsible or body is FlyingShard or _in_geometry(room, body):
				solids.append(_hull(local, size))
		elif node is Ladder:
			ladders.append(Vector3(_r(local.origin.x), _r(local.origin.y), _r(local.origin.y + (node as Ladder).height)))
		elif node is RoomDoor:
			doors.append([Vector2(_r(local.origin.x), _r(local.origin.y)), (node as RoomDoor).target_room])
		elif node is MirrorShard:
			shards[String(room.get_path_to(node))] = Vector2(_r(local.origin.x), _r(local.origin.y))
	# Границы по высоте — от самого низкого пола до самого высокого, с запасом.
	var floors: Array[float] = []
	for poly in _clip_all(solids + glass, left, right, -1000.0, 1000.0):
		var top := -INF
		for p in poly:
			top = maxf(top, p.y)
		floors.append(top)
	var bottom: float = (floors.min() - FOOTROOM) if floors.size() > 0 else -2.0
	var top_y: float = (floors.max() + HEADROOM) if floors.size() > 0 else 6.0
	return {"left": left, "right": right, "bottom": _r(bottom), "top": _r(top_y),
		"solids": _clip_all(solids, left, right, bottom, top_y), "glass": _clip_all(glass, left, right, bottom, top_y),
		"ladders": ladders, "doors": doors, "shards": shards}


static func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


static func _in_geometry(room: Room, node: Node) -> bool:
	var geometry := room.get_node_or_null(^"Geometry")
	return geometry != null and geometry.is_ancestor_of(node)


## Проекция коробки на плоскость кадра (x, y): выпуклая оболочка восьми углов.
static func _hull(xf: Transform3D, size: Vector3) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var corner := Vector3(size.x * (0.5 if i & 1 else -0.5), size.y * (0.5 if i & 2 else -0.5), size.z * (0.5 if i & 4 else -0.5))
		var p := xf * corner
		points.append(Vector2(p.x, p.y))
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1:
		hull.remove_at(hull.size() - 1)  # convex_hull повторяет первую точку в конце
	return hull


static func _clip_all(polys: Array[PackedVector2Array], left: float, right: float, bottom: float, top: float) -> Array[PackedVector2Array]:
	var frame := PackedVector2Array([Vector2(left, bottom), Vector2(right, bottom), Vector2(right, top), Vector2(left, top)])
	var result: Array[PackedVector2Array] = []
	for poly in polys:
		for piece in Geometry2D.intersect_polygons(poly, frame):
			var rounded := PackedVector2Array()
			for p in piece:
				rounded.append(Vector2(_r(p.x), _r(p.y)))
			if rounded.size() >= 3:
				result.append(rounded)
	return result


static func _r(v: float) -> float:
	return snappedf(v, 0.01)
