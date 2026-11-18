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
const CELL := 30.0
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.2
## Скорость панорамы стиком и клавишами, пикс/с.
const PAN_SPEED := 700.0
## Сдвиг мыши, после которого нажатие — уже перетаскивание, а не щелчок.
const DRAG_SLOP := 6.0

const PAPER := Color(0.03, 0.03, 0.035, 0.97)
## Стены комнат и коридоров — тусклая бронза.
const WALL := Color(0.69, 0.56, 0.38)
const AREA_NAME := Color(0.93, 0.91, 0.86)
const SHARD_LIT := Color(0.62, 0.92, 1.0)
const SHARD_DARK := Color(0.55, 0.6, 0.66)
const HERO := Color(1.0, 0.72, 0.38)

var dev := false
var current_room: StringName
## Где герой в своей комнате, по ширине от 0 до 1.
var hero_t := 0.5
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
func open(room: StringName, t: float, dev_mode: bool) -> void:
	dev = dev_mode
	current_room = room
	hero_t = t
	_zoom = 1.0
	_pan = Vector2.ZERO
	if WorldMap.ROOMS.has(room):
		_pan = -WorldMap.room_rect(room).get_center() * CELL
	_legend.text = ("Тестовый режим: открыто всё · щелчок по осколку — перенестись к нему    " if dev else "") \
		+ "◆ осколок   ◇ не зажжён   ▼ ты здесь    Тяни мышью — двигать карту, колесо — масштаб, наведи — имя места"
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
	for room: StringName in WorldMap.SHARDS:
		if dev or GameState.visited(room):
			var at := _to_screen(WorldMap.room_point(room, WorldMap.SHARDS[room]["x"]))
			spots[room] = Rect2(at - Vector2(10, 10), Vector2(20, 20))
	return spots


## Пан в пикселях: тесты двигают карту так же, как мышь.
func pan_by(delta: Vector2) -> void:
	_pan += delta
	_canvas.queue_redraw()


func pan() -> Vector2:
	return _pan


## Перенос к осколку — только в тестовом режиме.
func choose_shard(room: StringName) -> void:
	if dev and WorldMap.SHARDS.has(room):
		shard_chosen.emit(room, WorldMap.SHARDS[room]["path"])


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
	# Сначала заливка, потом стены: у соседних комнат стена общая.
	for room in shown:
		_canvas.draw_rect(_rect_px(WorldMap.room_rect(room)), _fill(room))
	_draw_links(shown, true)
	for room in shown:
		_canvas.draw_rect(_rect_px(WorldMap.room_rect(room)), WALL, false, _wall())
	_draw_links(shown, false)
	_draw_shards()
	_draw_area_names(shown)
	if WorldMap.ROOMS.has(current_room):
		_draw_hero(_to_screen(WorldMap.room_point(current_room, (hero_t - 0.5) * WorldMap.ROOMS[current_room]["w"])))
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


## Проходы: у соседних комнат — разрыв в общей стене, у далёких — коридор от стены до стены,
## в неоткрытое — обрывок коридора. under — проход до стен (тело коридора), иначе — разрывы поверх стен.
func _draw_links(shown: Array[StringName], under: bool) -> void:
	var door := clampf(12.0 * _zoom, 8.0, 20.0)
	for link: Array in WorldMap.LINKS:
		var a: StringName = link[0]
		var b: StringName = link[1]
		var has_a := shown.has(a)
		var has_b := shown.has(b)
		if not has_a and not has_b:
			continue
		var ca := _to_screen(WorldMap.room_rect(a).get_center())
		var cb := _to_screen(WorldMap.room_rect(b).get_center())
		var ea := _edge_toward(a, cb)
		var eb := _edge_toward(b, ca)
		if not (has_a and has_b):
			# Обрывок: из открытой комнаты на шаг в сторону неоткрытой.
			var from := ea if has_a else eb
			var dir := ((cb - ca) if has_a else (ca - cb)).normalized()
			eb = from + dir * 22.0 * _zoom
			ea = from
		var fill := _fill(a if has_a else b)
		if ea.distance_to(eb) < 3.0:
			if not under:
				# Разрыв в стене: проём шириной door поперёк стены.
				var along := Vector2(0, 1) if absf((cb - ca).x) > absf((cb - ca).y) else Vector2(1, 0)
				_canvas.draw_line(ea - along * door * 0.5, ea + along * door * 0.5, fill, _wall() + 2.0)
			continue
		var width := door * 0.9
		if under:
			_canvas.draw_line(ea, eb, WALL, width + _wall() * 2.0)
			_canvas.draw_line(ea, eb, fill, width)
		else:
			# Устье коридора прорезает стену комнаты.
			var mouths: Array[Vector2] = [ea, eb] if has_a and has_b else [ea]
			for mouth in mouths:
				_canvas.draw_circle(mouth, width * 0.5, fill)


## Точка на краю комнаты в сторону цели.
func _edge_toward(room: StringName, target: Vector2) -> Vector2:
	var r := _rect_px(WorldMap.room_rect(room))
	var c := r.get_center()
	var d := target - c
	if d == Vector2.ZERO:
		return c
	var k := minf(absf(r.size.x * 0.5 / d.x) if d.x != 0.0 else INF, absf(r.size.y * 0.5 / d.y) if d.y != 0.0 else INF)
	return c + d * k


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
