class_name WorldMapView
extends VBoxContainer
## Карта мира (§8.13): окно неподвижно, содержимое тянется мышью (или стиком/стрелками), колесо — масштаб.
## Вид — по карте Mandragora: комнаты залиты приглушённым цветом биома и обведены толстыми бронзовыми стенами,
## проходы — разрывы в стенах и короткие коридоры, имя области — крупно поверх неё; имя комнаты — под курсором.
## Видны только комнаты, где герой уже был (`GameState.visited_rooms`): мир открывается по мере пути.
## Биом подписан, когда открыта хоть одна его комната; дверь в неоткрытую комнату — обрывок линии.
## Осколки — ромбы: зажжённый светится, незажжённый — контур.
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
## Стены комнат и коридоров — тусклая бронза.
const WALL := Color(0.69, 0.56, 0.38)
const AREA_NAME := Color(0.93, 0.91, 0.86)
## Линия пола и уступов, стекло на карте.
const FLOOR := Color(0.9, 0.86, 0.76)
const GLASS := Color(0.6, 0.85, 1.0)
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
	if WorldMap.ROOMS.has(room):
		_pan = -WorldMap.room_rect(room).get_center() * CELL
	_legend.text = ("Тест: открыто всё, щелчок по осколку — перенос    " if dev else "") \
		+ "◆ осколок   ◇ не зажжён   ▼ ты здесь    тяни — двигать, колесо — масштаб"
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
	# Сначала коридоры и воздух комнат, потом твёрдое, стены и линии пола: у соседних комнат стык общий.
	_draw_links(shown)
	for room in shown:
		_canvas.draw_rect(_rect_px(WorldMap.room_rect(room)), _fill(room))
	for room in shown:
		_draw_room(room)
	_draw_shards()
	_draw_area_names(shown)
	if WorldMap.ROOMS.has(current_room):
		_draw_hero(_to_screen(WorldMap.to_map(current_room, hero_at)))
	if _hover_room != &"":
		var r := _rect_px(WorldMap.room_rect(_hover_room))
		_canvas.draw_rect(r, Color(1, 1, 1, 0.06))
		_text(Vector2(r.position.x, r.end.y + 18.0), LevelMenu.place_name(_hover_room), 15, AREA_NAME)


## Толщина стены: с масштабом, но не тоньше 2 пикс.
func _wall() -> float:
	return clampf(3.0 * _zoom, 2.0, 5.0)


## Заливка комнаты — приглушённый цвет её биома; комната героя светлее.
func _fill(room: StringName) -> Color:
	var color: Color = WorldMap.BIOMES[WorldMap.ROOMS[room]["biome"]]["color"]
	var dark := Color(color.darkened(0.68), 1.0)
	dark.s *= 0.75
	return dark.lightened(0.12) if room == current_room else dark


func _draw_planned(biome: StringName) -> void:
	var r := _rect_px(WorldMap.BIOMES[biome]["planned"])
	var color: Color = WorldMap.BIOMES[biome]["color"]
	_canvas.draw_rect(r, Color(color.darkened(0.75), 0.5))
	_dashed_rect(r, Color(WALL, 0.45))
	_text(r.position + Vector2(10, 30), WorldMap.biome_name(biome), 24, Color(AREA_NAME, 0.45), true)
	_text(r.position + Vector2(10, 50), "в плане", 14, Color(AREA_NAME, 0.35))


## Имя области — крупно, светлым по тёмному, над её комнатами.
func _draw_area_names(shown: Array[StringName]) -> void:
	var areas := {}
	for room in shown:
		var biome: StringName = WorldMap.ROOMS[room]["biome"]
		var r := WorldMap.room_rect(room)
		areas[biome] = (areas[biome] as Rect2).merge(r) if areas.has(biome) else r
	var size := int(clampf(26.0 * _zoom, 16.0, 40.0))
	for biome: StringName in areas:
		var r := _rect_px(areas[biome])
		var at := Vector2(r.position.x + 4.0, r.position.y - 10.0)
		_text(at + Vector2(2, 2), WorldMap.biome_name(biome), size, Color(0, 0, 0, 0.8), true)
		_text(at, WorldMap.biome_name(biome), size, AREA_NAME, true)


## Комната — её силуэт: твёрдое (земля, уступы, стены) почти чёрным с бронзовой кромкой, верх твёрдого —
## светлая линия пола; стекло — голубым, лестницы — перекладинами, двери — арками. Рамка комнаты — тонкая.
func _draw_room(room: StringName) -> void:
	var s := WorldMap.shape(room)
	var wall := _wall()
	for poly: PackedVector2Array in s.get("solids", []):
		var pts := _poly_px(room, poly)
		if pts.size() >= 3:
			_canvas.draw_colored_polygon(pts, PAPER)
			_outline(pts, Color(WALL, 0.55), 1.0)
			_floor_lines(pts, wall)
	for poly: PackedVector2Array in s.get("glass", []):
		var pts := _poly_px(room, poly)
		if pts.size() >= 3:
			_canvas.draw_colored_polygon(pts, Color(GLASS, 0.35))
			_outline(pts, GLASS, 1.0)
	for ladder: Vector3 in s.get("ladders", []):
		_draw_ladder(room, ladder)
	for door: Array in s.get("doors", []):
		_draw_door(_to_screen(WorldMap.to_map(room, door[0])))
	_canvas.draw_rect(_rect_px(WorldMap.room_rect(room)), Color(WALL, 0.8), false, 1.5)


func _poly_px(room: StringName, poly: PackedVector2Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(_to_screen(WorldMap.to_map(room, p)))
	return pts


func _outline(pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	_canvas.draw_polyline(closed, color, width)


## Пол и уступы: рёбра твёрдого, по которым можно стоять (почти горизонтальные и сверху), — светлой линией.
func _floor_lines(pts: PackedVector2Array, width: float) -> void:
	var n := pts.size()
	var center := Vector2.ZERO
	for p in pts:
		center += p
	center /= n
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := b - a
		if d.length() < 2.0 or absf(d.y) > absf(d.x) * 0.9:
			continue
		# Ребро сверху: середина ребра выше центра фигуры (y экрана — вниз).
		if (a.y + b.y) * 0.5 < center.y:
			_canvas.draw_line(a, b, FLOOR, width)


func _draw_ladder(room: StringName, ladder: Vector3) -> void:
	var low := _to_screen(WorldMap.to_map(room, Vector2(ladder.x, ladder.y)))
	var high := _to_screen(WorldMap.to_map(room, Vector2(ladder.x, ladder.z)))
	var w := clampf(4.0 * _zoom, 3.0, 7.0)
	_canvas.draw_line(low + Vector2(-w, 0), high + Vector2(-w, 0), Color(WALL, 0.9), 1.0)
	_canvas.draw_line(low + Vector2(w, 0), high + Vector2(w, 0), Color(WALL, 0.9), 1.0)
	var steps := int(absf(low.y - high.y) / maxf(5.0 * _zoom, 4.0))
	for i in steps:
		var y := lerpf(low.y, high.y, (i + 0.5) / steps)
		_canvas.draw_line(Vector2(low.x - w, y), Vector2(low.x + w, y), Color(WALL, 0.9), 1.0)


## Дверь — арка на полу.
func _draw_door(at: Vector2) -> void:
	var k := clampf(_zoom, 0.8, 1.5)
	var w := 5.0 * k
	var h := 11.0 * k
	var arch := PackedVector2Array([at + Vector2(-w, 0), at + Vector2(-w, -h * 0.6)])
	for i in 7:
		var a := PI + PI * i / 6.0
		arch.append(at + Vector2(0, -h * 0.6) + Vector2(cos(a) * w, sin(a) * w * 0.8))
	arch.append(at + Vector2(w, 0))
	_canvas.draw_colored_polygon(arch, Color(0.08, 0.07, 0.06))
	_canvas.draw_polyline(arch, WALL, 1.5)


## Проходы между комнатами — коридор от двери до двери (у соседних комнат он короткий, почти незаметный),
## в неоткрытую комнату — обрывок коридора в её сторону.
func _draw_links(shown: Array[StringName]) -> void:
	var width := clampf(9.0 * _zoom, 6.0, 16.0)
	for room in shown:
		for door: Array in WorldMap.shape(room).get("doors", []):
			var target: StringName = door[1]
			if not WorldMap.ROOMS.has(target):
				continue
			var from := _to_screen(WorldMap.to_map(room, door[0]))
			var to := _door_toward(target, room)
			if not shown.has(target):
				to = from + (to - from).normalized() * 24.0 * _zoom
			elif String(target) < String(room):
				continue  # пару рисует одна из двух комнат
			if from.distance_to(to) > 1.2 * CELL * _zoom:
				# Дальний переход (дверь в другую часть мира) — пунктир, а не коридор.
				_canvas.draw_dashed_line(from, to, Color(WALL, 0.7), 1.5, 7.0)
				continue
			var fill := _fill(room)
			_canvas.draw_line(from, to, WALL, width + _wall() * 2.0)
			_canvas.draw_line(from, to, fill, width)


## Дверь комнаты target, ведущая в from (центр комнаты, если такой двери нет).
func _door_toward(target: StringName, from: StringName) -> Vector2:
	for door: Array in WorldMap.shape(target).get("doors", []):
		if door[1] == from:
			return _to_screen(WorldMap.to_map(target, door[0]))
	return _to_screen(WorldMap.room_rect(target).get_center())


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
		var outline := crystal.duplicate()
		outline.append(crystal[0])
		_canvas.draw_polyline(outline, SHARD_LIT if lit else SHARD_DARK, 1.5)
		if room == _hover:
			_text(c + Vector2(14, -12), "Перенестись: %s" % LevelMenu.place_name(room), 15, LevelMenu.ACCENT)


## Герой — булавка: остриё в точке, где он стоит.
func _draw_hero(at: Vector2) -> void:
	var k := clampf(_zoom, 0.8, 1.4)
	var head := at + Vector2(0, -16.0 * k)
	_canvas.draw_colored_polygon(PackedVector2Array([at, head + Vector2(-5.5 * k, 3.0 * k), head + Vector2(5.5 * k, 3.0 * k)]), HERO)
	_canvas.draw_circle(head, 7.0 * k, HERO)
	_canvas.draw_circle(head, 3.0 * k, Color(0.1, 0.07, 0.04))


func _text(at: Vector2, text: String, size: int, color: Color, serif := false, width := -1.0) -> void:
	_canvas.draw_string(_serif if serif else _font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


func _dashed_rect(r: Rect2, color: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		_canvas.draw_dashed_line(corners[i], corners[i + 1], color, 1.5, 8.0)
