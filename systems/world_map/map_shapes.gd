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
## Высота «воздуха» над полом и уступом, м: так высоко комната видна на карте над каждой поверхностью.
const BAND := 3.4
## Ребро круче этого (по отношению высоты к длине) — уже стена, а не пол.
const STEEP := 1.2
## Пол выше самой высокой лестницы, двери или кольца крюка больше чем на это — крыша или потолок, герою туда не попасть.
const REACH := 3.5

## id комнаты → {left, right, bottom, top (м), solids, glass (Array[PackedVector2Array]),
## space — «воздух» комнаты, по которому ходит герой: на карте комната — это его очертание (Array[PackedVector2Array]),
## pillars — твёрдое внутри воздуха (колонны, уступы посреди хода), ladders (Array[Vector3]: x, низ, верх),
## doors (Array: [Vector2, id комнаты]), shards ({путь: Vector2})}.
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
	var hooks: Array[float] = []
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
		elif node is HookPoint:
			hooks.append(local.origin.y)
	# Границы по высоте — от самого низкого пола до самого высокого, с запасом.
	var floors: Array[float] = []
	for poly in _clip_all(solids + glass, left, right, -1000.0, 1000.0):
		var top := -INF
		for p in poly:
			top = maxf(top, p.y)
		floors.append(top)
	var bottom: float = (floors.min() - FOOTROOM) if floors.size() > 0 else -2.0
	var top_y: float = (floors.max() + HEADROOM) if floors.size() > 0 else 6.0
	var clipped_solids := _clip_all(solids, left, right, bottom, top_y)
	var clipped_glass := _clip_all(glass, left, right, bottom, top_y)
	var air := _space(clipped_solids, clipped_glass, ladders, doors, hooks, left, right, bottom, top_y)
	return {"left": left, "right": right, "bottom": _r(bottom), "top": _r(top_y),
		"solids": clipped_solids, "glass": clipped_glass, "space": _rounded(air[0]), "pillars": _rounded(air[1]),
		"ladders": ladders, "doors": doors, "shards": shards}


## Воздух комнаты: полоса BAND над каждым полом и уступом (верхние пологие рёбра твёрдого и стекла),
## шахты лестниц, проёмы дверей — всё вместе, без твёрдого. Возвращает [воздух, твёрдое внутри воздуха].
static func _space(solids: Array[PackedVector2Array], glass: Array[PackedVector2Array], ladders: Array[Vector3],
		doors: Array, hooks: Array[float], left: float, right: float, bottom: float, top: float) -> Array:
	var bands: Array[PackedVector2Array] = []
	# Докуда герой может добраться: лестницы, двери, кольца крюка, первый пол; выше — крыши и потолки, их воздух не нужен.
	var reach := -INF
	for ladder in ladders:
		reach = maxf(reach, ladder.z)
	for door: Array in doors:
		reach = maxf(reach, (door[0] as Vector2).y)
	for hook in hooks:
		reach = maxf(reach, hook)
	if reach == -INF:
		reach = 0.0
	reach += REACH
	for poly in solids + glass:
		var center := Vector2.ZERO
		for p in poly:
			center += p
		center /= poly.size()
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			if a.x > b.x:
				var swap := a
				a = b
				b = swap
			var d := b - a
			if d.length() < 0.2 or absf(d.y) > absf(d.x) * STEEP or (a.y + b.y) * 0.5 < center.y or minf(a.y, b.y) > reach:
				continue
			bands.append(PackedVector2Array([a, b, b + Vector2(0, BAND), a + Vector2(0, BAND)]))
	for ladder in ladders:
		bands.append(_box(ladder.x - 0.7, ladder.y, ladder.x + 0.7, ladder.z + 1.2))
	for door: Array in doors:
		var at: Vector2 = door[0]
		bands.append(_box(at.x - 1.2, at.y, at.x + 1.2, at.y + 3.0))
	var air := _union(bands, 0.06)
	# Твёрдое вырезается из воздуха; то, что оказалось целиком внутри (колонна посреди хода), — отдельно.
	var pillars: Array[PackedVector2Array] = []
	for solid in solids:
		var next: Array[PackedVector2Array] = []
		for piece in air:
			var parts := Geometry2D.clip_polygons(piece, solid)
			for part in parts:
				if _is_hole(part, parts):
					pillars.append(solid)
				else:
					next.append(part)
		air = next
	return [_clip_all(air, left, right, bottom, top), pillars]


static func _box(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## Объединение многоугольников; grow — нахлёст, чтобы касающиеся куски слились, а не остались швом.
static func _union(polys: Array[PackedVector2Array], grow: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for poly in polys:
		var grown := Geometry2D.offset_polygon(poly, grow, Geometry2D.JOIN_MITER)
		if grown.is_empty():
			continue
		var current: PackedVector2Array = grown[0]
		var i := 0
		while i < result.size():
			if Geometry2D.intersect_polygons(current, result[i]).is_empty():
				i += 1
				continue
			# Внешний контур — самый большой кусок слияния (дыры отбрасываем — у воздуха их почти не бывает).
			var best := -1.0
			for part in Geometry2D.merge_polygons(current, result[i]):
				var area := absf(_area(part))
				if area > best:
					best = area
					current = part
			result.remove_at(i)
			i = 0
		result.append(current)
	return result


## Кусок — дыра, если он лежит внутри другого куска того же разреза (направление обхода у Clipper ненадёжно).
static func _is_hole(part: PackedVector2Array, parts: Array[PackedVector2Array]) -> bool:
	for other in parts:
		if other != part and absf(_area(other)) > absf(_area(part)) and Geometry2D.is_point_in_polygon(part[0], other):
			return true
	return false


static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


static func _rounded(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for poly in polys:
		var rounded := PackedVector2Array()
		for p in poly:
			rounded.append(Vector2(_r(p.x), _r(p.y)))
		if rounded.size() >= 3:
			result.append(rounded)
	return result


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
