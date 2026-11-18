class_name WorldMapView
extends VBoxContainer
## Карта мира (§8.13): окно неподвижно, содержимое тянется мышью (или стиком/стрелками), колесо — масштаб.
## Комната — очертание её «воздуха», по которому ходит герой (MapShapes: полосы над полом и уступами, шахты
## лестниц), а не прямоугольник. Стены — только по общему внешнему контуру открытых комнат: соседние комнаты
## сливаются в один ход, на месте двери — проём, без стрелок. Дальний переход (зеркало, дверь в другую часть мира) —
## готические врата с подписью, куда ведут; проход в неоткрытую комнату — проём, уходящий в темноту.
## Вид готический: стены кладкой с бронзовой кромкой, рама с остроконечными уголками, имена областей в орнаменте.
## Видны только комнаты, где герой уже был (`GameState.visited_rooms`): мир открывается по мере пути.
## Осколки — кристалл на подставке: зажжённый светится, незажжённый — тёмный.
## Тестовый режим (`dev`, клавиша F4): открыто всё, даже области в плане; щелчок по осколку — перенос к нему.

signal shard_chosen(room: StringName, path: NodePath)

## Пикселей в единице карты при масштабе 1.
const CELL := 56.0
const ZOOM_MIN := 0.25
const ZOOM_MAX := 2.5
## Скорость панорамы стиком и клавишами, пикс/с.
const PAN_SPEED := 700.0
## Сдвиг мыши, после которого нажатие — уже перетаскивание, а не щелчок.
const DRAG_SLOP := 6.0

const PAPER := Color(0.03, 0.03, 0.035, 0.97)
## Стены: тёмная кладка снаружи, тусклая бронза по кромке.
const WALL := Color(0.69, 0.56, 0.38)
const MASONRY := Color(0.13, 0.11, 0.09)
const AREA_NAME := Color(0.93, 0.91, 0.86)
const GLASS := Color(0.6, 0.85, 1.0)
## Дальний переход ближе этого (в единицах карты) — уже не врата, а соседний ход.
const NEAR_DOOR := 1.6
const SHARD_LIT := Color(0.62, 0.92, 1.0)
const SHARD_DARK := Color(0.55, 0.6, 0.66)
const HERO := Color(1.0, 0.72, 0.38)

var dev := false
var current_room: StringName
## Где герой в своей комнате, м.
var hero_at := Vector2.ZERO
var _pan := Vector2.ZERO
var _zoom := 1.0
var _pressed := false
var _dragged := 0.0
var _hover: StringName
var _hover_room: StringName
var _canvas: Control
var _legend: Label
var _font: Font
var _serif: Font
## Внешний контур открытых комнат в единицах карты — пересчитывается, когда меняется набор комнат.
var _walls: Array[PackedVector2Array] = []
## Подписи врат, уже поставленные в этом кадре: следующая не ложится поверх.
var _labels: Array[Rect2] = []


func setup(menu: LevelMenu) -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_serif = menu._serif_font
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var plate := StyleBoxFlat.new()
	plate.bg_color = PAPER
	plate.border_color = Color(0.55, 0.52, 0.47, 0.85)
	plate.set_border_width_all(2)
	plate.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", plate)
	add_child(frame)
	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.focus_mode = Control.FOCUS_ALL
	_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
	frame.add_child(_canvas)
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_input)
	_legend = menu._label(self, "", 17, LevelMenu.MUTED)
	_font = get_theme_default_font()


## Открыть карту: комната героя — посередине окна.
func open(room: StringName, hero: Vector2, dev_mode: bool) -> void:
	dev = dev_mode
	current_room = room
	hero_at = hero
	_zoom = 1.0
	_pan = Vector2.ZERO
	center_on(room)
	_legend.text = ("Тест: открыто всё, щелчок по осколку — перенос    " if dev else "") \
		+ "◆ осколок   ◇ не зажжён   ▼ ты здесь   ⌂ переход    тяни — двигать, колесо — масштаб"
	_rebuild_walls()
	_canvas.queue_redraw()


## Общий контур воздуха открытых комнат: касающиеся комнаты сливаются, и стена между ними пропадает.
func _rebuild_walls() -> void:
	var polys: Array[PackedVector2Array] = []
	for room in shown_rooms():
		for poly: PackedVector2Array in WorldMap.shape(room).get("space", []):
			polys.append(_map_poly(room, poly))
	_walls = MapShapes._union(polys, 0.025)


## Комната — посередине окна.
func center_on(room: StringName) -> void:
	if WorldMap.ROOMS.has(room):
		_pan = -WorldMap.room_rect(room).get_center() * CELL * _zoom
		_canvas.queue_redraw()


func focus() -> void:
	_canvas.grab_focus()


## Комнаты, которые видно на карте.
func shown_rooms() -> Array[StringName]:
	var result: Array[StringName] = []
	for room: StringName in WorldMap.ROOMS:
		if dev or GameState.visited(room):
			result.append(room)
	return result


## Осколки на карте: комната → прямоугольник ромба в пикселях окна (для щелчка и тестов).
func shard_spots() -> Dictionary:
	var spots := {}
	for room: StringName in WorldMap.shards():
		if dev or GameState.visited(room):
			var at := _to_screen(WorldMap.shard_point(room))
			spots[room] = Rect2(at - Vector2(10, 14), Vector2(20, 24))
	return spots


## Пан в пикселях: тесты двигают карту так же, как мышь.
func pan_by(delta: Vector2) -> void:
	_pan += delta
	_canvas.queue_redraw()


func pan() -> Vector2:
	return _pan


## Перенос к осколку — только в тестовом режиме.
func choose_shard(room: StringName) -> void:
	var shards := WorldMap.shards()
	if dev and shards.has(room):
		shard_chosen.emit(room, shards[room])


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	move += Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if move.length() > 0.1:
		pan_by(-move.limit_length(1.0) * PAN_SPEED * delta)


func _on_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, 1.15)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 1.0 / 1.15)
		elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if button.pressed:
				_pressed = true
				_dragged = 0.0
				_canvas.grab_focus()
			elif _pressed:
				_pressed = false
				if _dragged < DRAG_SLOP and button.button_index == MOUSE_BUTTON_LEFT:
					_click(button.position)
		_canvas.accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion:
		if _pressed:
			_dragged += motion.relative.length()
			pan_by(motion.relative)
		else:
			_hover_at(motion.position)
		_canvas.accept_event()


func _zoom_at(at: Vector2, factor: float) -> void:
	var before := _to_map(at)
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	# Точка под курсором остаётся под курсором.
	_pan += at - _to_screen(before)
	_canvas.queue_redraw()


func _click(at: Vector2) -> void:
	var spots := shard_spots()
	for room: StringName in spots:
		if (spots[room] as Rect2).grow(4).has_point(at):
			choose_shard(room)
			return


func _hover_at(at: Vector2) -> void:
	var was := _hover
	var was_room := _hover_room
	_hover = &""
	_hover_room = &""
	var spot := _to_map(at)
	for room in shown_rooms():
		if WorldMap.room_rect(room).has_point(spot):
			_hover_room = room
	if dev:
		var spots := shard_spots()
		for room: StringName in spots:
			if (spots[room] as Rect2).grow(4).has_point(at):
				_hover = room
	_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover != &"" else Control.CURSOR_DRAG
	if was != _hover or was_room != _hover_room:
		_canvas.queue_redraw()


func _origin() -> Vector2:
	return _canvas.size * 0.5 + _pan


func _to_screen(p: Vector2) -> Vector2:
	return _origin() + p * CELL * _zoom


func _to_map(at: Vector2) -> Vector2:
	return (at - _origin()) / (CELL * _zoom)


func _rect_px(r: Rect2) -> Rect2:
	return Rect2(_to_screen(r.position), r.size * CELL * _zoom)


# ---------------------------------------------------------------- рисование

func _draw_map() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var shown := shown_rooms()
	if dev:
		for biome: StringName in WorldMap.BIOMES:
			if WorldMap.is_planned(biome):
				_draw_planned(biome)
	# Кладка — широкая тёмная обводка под воздухом: стены получаются толстыми, как на старой карте.
	var wall := _wall()
	for poly in _walls:
		_outline(_screen_poly(poly), MASONRY, wall * 3.0)
	for room in shown:
		_draw_room(room)
	for poly in _walls:
		_outline(_screen_poly(poly), WALL, wall)
	_draw_passages(shown)
	_draw_shards()
	_draw_area_names(shown)
	if WorldMap.ROOMS.has(current_room):
		_draw_hero(_to_screen(WorldMap.to_map(current_room, hero_at)))
	if _hover_room != &"":
		var r := _rect_px(WorldMap.room_rect(_hover_room))
		_text(Vector2(r.position.x, r.end.y + 20.0), LevelMenu.place_name(_hover_room), 16, AREA_NAME, true)
	_draw_frame(size)


## Толщина бронзовой кромки: с масштабом, но не тоньше 2 пикс.
func _wall() -> float:
	return clampf(2.5 * _zoom, 2.0, 4.5)


## Заливка комнаты — приглушённый цвет её биома; комната героя светлее.
func _fill(room: StringName) -> Color:
	var color: Color = WorldMap.BIOMES[WorldMap.ROOMS[room]["biome"]]["color"]
	var dark := Color(color.darkened(0.66), 1.0)
	dark.s *= 0.7
	return dark.lightened(0.12) if room == current_room else dark


func _draw_planned(biome: StringName) -> void:
	var r := _rect_px(WorldMap.BIOMES[biome]["planned"])
	var color: Color = WorldMap.BIOMES[biome]["color"]
	_canvas.draw_rect(r, Color(color.darkened(0.78), 0.45))
	_dashed_rect(r, Color(WALL, 0.4))
	_title(r.position + Vector2(r.size.x * 0.5, 34), WorldMap.biome_name(biome), 22, Color(AREA_NAME, 0.45))
	_text(r.position + Vector2(r.size.x * 0.5 - 24, 54), "в плане", 13, Color(AREA_NAME, 0.35))


## Комната: воздух цветом биома, колонны и уступы посреди хода — тёмной кладкой, стекло, лестницы.
func _draw_room(room: StringName) -> void:
	var s := WorldMap.shape(room)
	var fill := _fill(room)
	for poly: PackedVector2Array in s.get("space", []):
		var pts := _screen_poly(_map_poly(room, poly))
		if pts.size() >= 3:
			_canvas.draw_colored_polygon(pts, fill)
	for poly: PackedVector2Array in s.get("pillars", []):
		var pts := _screen_poly(_map_poly(room, poly))
		if pts.size() >= 3:
			_canvas.draw_colored_polygon(pts, MASONRY)
			_outline(pts, WALL, 1.5)
	for poly: PackedVector2Array in s.get("glass", []):
		var pts := _screen_poly(_map_poly(room, poly))
		if pts.size() >= 3:
			_canvas.draw_colored_polygon(pts, Color(GLASS, 0.3))
			_outline(pts, Color(GLASS, 0.8), 1.0)
	for ladder: Vector3 in s.get("ladders", []):
		_draw_ladder(room, ladder)


func _map_poly(room: StringName, poly: PackedVector2Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(WorldMap.to_map(room, p))
	return pts


func _screen_poly(poly: PackedVector2Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(_to_screen(p))
	return pts


func _outline(pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	_canvas.draw_polyline(closed, color, width, true)


func _draw_ladder(room: StringName, ladder: Vector3) -> void:
	var low := _to_screen(WorldMap.to_map(room, Vector2(ladder.x, ladder.y)))
	var high := _to_screen(WorldMap.to_map(room, Vector2(ladder.x, ladder.z)))
	var w := clampf(3.5 * _zoom, 2.5, 6.0)
	var color := Color(WALL, 0.85)
	_canvas.draw_line(low + Vector2(-w, 0), high + Vector2(-w, 0), color, 1.0)
	_canvas.draw_line(low + Vector2(w, 0), high + Vector2(w, 0), color, 1.0)
	var steps := int(absf(low.y - high.y) / maxf(5.0 * _zoom, 4.0))
	for i in steps:
		var y := lerpf(low.y, high.y, (i + 0.5) / steps)
		_canvas.draw_line(Vector2(low.x - w, y), Vector2(low.x + w, y), color, 1.0)


## Переходы: соседняя открытая комната уже слилась с этой в один ход — рисовать нечего. Дальняя — врата с
## подписью, куда ведут. Неоткрытая соседняя — проём в стене, уходящий в темноту; неоткрытая дальняя — врата без имени.
func _draw_passages(shown: Array[StringName]) -> void:
	_labels.clear()
	for room in shown:
		for door: Array in WorldMap.shape(room).get("doors", []):
			var target: StringName = door[1]
			if not WorldMap.ROOMS.has(target):
				continue
			var here := WorldMap.to_map(room, door[0])
			var partner := _partner(target, room)
			var near := partner.distance_to(here) < NEAR_DOOR
			if shown.has(target):
				if not near:
					_draw_gate(_to_screen(here), LevelMenu.place_name(target), true)
			elif near:
				_draw_opening(room, door[0], partner)
			else:
				_draw_gate(_to_screen(here), "", false)


## Дверь комнаты target, ведущая в from, на карте (центр комнаты, если такой двери нет).
func _partner(target: StringName, from: StringName) -> Vector2:
	for door: Array in WorldMap.shape(target).get("doors", []):
		if door[1] == from:
			return WorldMap.to_map(target, door[0])
	return WorldMap.room_rect(target).get_center()


## Проём в неоткрытое: стена расступается у края комнаты, ход уходит в темноту.
func _draw_opening(room: StringName, door: Vector2, toward: Vector2) -> void:
	var rect := WorldMap.room_rect(room)
	var floor_y := WorldMap.to_map(room, door).y
	var right := toward.x > rect.get_center().x
	var edge := rect.end.x if right else rect.position.x
	var height := MapShapes.BAND / WorldMap.METERS
	var a := _to_screen(Vector2(edge, floor_y))
	var b := _to_screen(Vector2(edge, floor_y - height))
	var out := Vector2(1.0 if right else -1.0, 0.0) * 0.9 * CELL * _zoom
	var fill := _fill(room)
	var fade := Color(fill, 0.0)
	_canvas.draw_polygon(PackedVector2Array([a, b, b + out, a + out]), PackedColorArray([fill, fill, fade, fade]))
	var dim := Color(WALL, 0.0)
	_canvas.draw_polyline_colors(PackedVector2Array([a, a + out]), PackedColorArray([WALL, dim]), _wall())
	_canvas.draw_polyline_colors(PackedVector2Array([b, b + out]), PackedColorArray([WALL, dim]), _wall())
	# Сама стена в проёме — стёрта цветом хода.
	_canvas.draw_line(a.lerp(b, 0.04), b.lerp(a, 0.04), fill, _wall() * 3.0 + 1.0)


## Готические врата — стрельчатая арка на полу; подпись — куда ведут.
func _draw_gate(at: Vector2, label: String, known: bool) -> void:
	var k := clampf(_zoom, 0.8, 1.6)
	var w := 7.0 * k
	var h := 20.0 * k
	var arch := PackedVector2Array([at + Vector2(-w, 0), at + Vector2(-w, -h * 0.5)])
	# Две дуги, сходящиеся в острие, — как в стрельчатом окне.
	for i in range(1, 6):
		var a := PI - PI / 3.0 * i / 5.0
		arch.append(at + Vector2(w, -h * 0.5) + Vector2(cos(a), -sin(a)) * w * 2.0)
	for i in range(1, 6):
		var a := PI / 3.0 - PI / 3.0 * i / 5.0
		arch.append(at + Vector2(-w, -h * 0.5) + Vector2(cos(a), -sin(a)) * w * 2.0)
	arch.append(at + Vector2(w, 0))
	var inner := Color(0.32, 0.42, 0.58) if known else Color(0.1, 0.1, 0.12)
	_canvas.draw_colored_polygon(arch, MASONRY)
	var glow := PackedVector2Array()
	for p in arch:
		glow.append(at + (p - at) * 0.62 + Vector2(0, -1.0 * k))
	_canvas.draw_colored_polygon(glow, inner)
	_outline(arch, WALL, 1.6)
	_canvas.draw_line(at + Vector2(-w - 3.0 * k, 0), at + Vector2(w + 3.0 * k, 0), WALL, 2.0)
	if label != "":
		var size := 14
		var width := _serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var spot := Rect2(at + Vector2(-width * 0.5, -h - 7.0 - size), Vector2(width, size + 4))
		# Соседние врата: подпись поднимается, пока не перестанет ложиться на прежние.
		var lifted := true
		while lifted:
			lifted = false
			for taken in _labels:
				if taken.intersects(spot):
					spot.position.y = taken.position.y - spot.size.y - 2.0
					lifted = true
		_labels.append(spot)
		var base := Vector2(spot.position.x, spot.end.y - 4.0)
		if base.y < at.y - h - 8.0:
			_canvas.draw_line(at + Vector2(0, -h - 2.0), Vector2(at.x, base.y + 2.0), Color(WALL, 0.5), 1.0)
		_text(base + Vector2(1, 1), label, size, Color(0, 0, 0, 0.8), true)
		_text(base, label, size, Color(AREA_NAME, 0.9), true)


## Имя области — крупно, между орнаментальными чертами, над её комнатами.
func _draw_area_names(shown: Array[StringName]) -> void:
	var areas := {}
	for room in shown:
		var biome: StringName = WorldMap.ROOMS[room]["biome"]
		var r := WorldMap.room_rect(room)
		areas[biome] = (areas[biome] as Rect2).merge(r) if areas.has(biome) else r
	var size := int(clampf(24.0 * _zoom, 16.0, 38.0))
	for biome: StringName in areas:
		var r := _rect_px(areas[biome])
		_title(Vector2(r.get_center().x, r.position.y - 14.0), WorldMap.biome_name(biome), size, AREA_NAME)


## Надпись с орнаментом: черта, ромб, имя, ромб, черта. at — середина базовой линии.
func _title(at: Vector2, text: String, size: int, color: Color) -> void:
	var width := _serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var left := at.x - width * 0.5
	_text(Vector2(left + 2, at.y + 2), text, size, Color(0, 0, 0, 0.85), true)
	_text(Vector2(left, at.y), text, size, color, true)
	var mid := at.y - size * 0.32
	var line := Color(WALL, color.a * 0.9)
	for side: float in [-1.0, 1.0]:
		var near := at.x + side * (width * 0.5 + 10.0)
		var far := near + side * size * 2.2
		_canvas.draw_line(Vector2(near + side * 6.0, mid), Vector2(far, mid), line, 1.2)
		_diamond(Vector2(near, mid), 4.0, line)
		_diamond(Vector2(far + side * 4.0, mid), 2.5, line)


func _diamond(c: Vector2, s: float, color: Color) -> void:
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), color)


## Осколок — кристалл на подставке: зажжённый светится, незажжённый — тёмный контур.
func _draw_shards() -> void:
	var spots := shard_spots()
	for room: StringName in spots:
		var c := (spots[room] as Rect2).get_center()
		var s := 7.0 * clampf(_zoom, 0.8, 1.5) * (1.35 if room == _hover else 1.0)
		var lit := GameState.has_flag(StringName("shard_%s" % room))
		var base := PackedVector2Array([c + Vector2(-s * 0.9, s * 1.25), c + Vector2(s * 0.9, s * 1.25),
			c + Vector2(s * 0.55, s * 0.7), c + Vector2(-s * 0.55, s * 0.7)])
		_canvas.draw_colored_polygon(base, WALL)
		var crystal := PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.6, -s * 0.1), c + Vector2(0, s * 0.7),
			c + Vector2(-s * 0.6, -s * 0.1)])
		if lit:
			_canvas.draw_circle(c, s * 1.7, Color(SHARD_LIT, 0.16))
		_canvas.draw_colored_polygon(crystal, SHARD_LIT if lit else Color(0.12, 0.13, 0.15))
		_outline(crystal, SHARD_LIT if lit else SHARD_DARK, 1.5)
		if room == _hover:
			_text(c + Vector2(14, -12), "Перенестись: %s" % LevelMenu.place_name(room), 15, LevelMenu.ACCENT)


## Герой — булавка: остриё в точке, где он стоит.
func _draw_hero(at: Vector2) -> void:
	var k := clampf(_zoom, 0.8, 1.4)
	var head := at + Vector2(0, -16.0 * k)
	_canvas.draw_colored_polygon(PackedVector2Array([at, head + Vector2(-5.5 * k, 3.0 * k), head + Vector2(5.5 * k, 3.0 * k)]), HERO)
	_canvas.draw_circle(head, 7.0 * k, HERO)
	_canvas.draw_circle(head, 3.0 * k, Color(0.1, 0.07, 0.04))


## Рама окна: затемнение к краям, двойная бронзовая черта и остроконечные уголки-фиалы.
func _draw_frame(size: Vector2) -> void:
	var edge := 70.0
	var dark := Color(0, 0, 0, 0.55)
	var clear := Color(0, 0, 0, 0)
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, edge), Vector2(0, edge)]),
		PackedColorArray([dark, dark, clear, clear]))
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, size.y - edge), Vector2(size.x, size.y - edge), size, Vector2(0, size.y)]),
		PackedColorArray([clear, clear, dark, dark]))
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(edge, 0), Vector2(edge, size.y), Vector2(0, size.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	_canvas.draw_polygon(PackedVector2Array([Vector2(size.x - edge, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x - edge, size.y)]),
		PackedColorArray([clear, dark, dark, clear]))
	for inset: float in [7.0, 12.0]:
		_canvas.draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(WALL, 0.55 if inset < 10.0 else 0.3), false, 1.0)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var c := Vector2(lerpf(12.0, size.x - 12.0, corner.x), lerpf(12.0, size.y - 12.0, corner.y))
		var dir := Vector2(1.0 if corner.x == 0.0 else -1.0, 1.0 if corner.y == 0.0 else -1.0)
		# Уголок-фиал: две черты вдоль рамы, ромб в углу и острие внутрь окна.
		_canvas.draw_line(c, c + Vector2(dir.x * 46.0, 0), WALL, 2.0)
		_canvas.draw_line(c, c + Vector2(0, dir.y * 46.0), WALL, 2.0)
		_diamond(c, 6.0, WALL)
		_canvas.draw_colored_polygon(PackedVector2Array([c + dir * 6.0, c + dir * 6.0 + Vector2(dir.x * 5.0, 0), c + dir * 20.0,
			c + dir * 6.0 + Vector2(0, dir.y * 5.0)]), Color(WALL, 0.8))
		_diamond(c + Vector2(dir.x * 52.0, 0), 2.5, WALL)
		_diamond(c + Vector2(0, dir.y * 52.0), 2.5, WALL)


func _text(at: Vector2, text: String, size: int, color: Color, serif := false, width := -1.0) -> void:
	_canvas.draw_string(_serif if serif else _font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


func _dashed_rect(r: Rect2, color: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		_canvas.draw_dashed_line(corners[i], corners[i + 1], color, 1.5, 8.0)
