class_name ItemPopup
extends Control
## Окно находки (§8.12): витая рамка с эмблемой, значок, название, сколько, «[E] ОК».
## Героя не останавливает: закрывается взаимодействием или само через SHOW_TIME. Несколько находок
## подряд — по очереди. Нажатие, закрывшее окно, ничего не подбирает (Player._try_interact).

const SHOW_TIME := 5.0
const FADE_TIME := 0.18
const FRAME := preload("res://assets/ui/hud/popup_frame.svg")
const FRAME_SIZE := Vector2(900, 220)

## Окно на экране: Player спрашивает его, чьё нажатие «взаимодействие».
static var current: ItemPopup

## Тесты выключают перехват нажатия, чтобы окно не съедало их «взаимодействие».
var blocks_interact := true
var queue: Array[StringName] = []
var shown: StringName
var _left := 0.0
var _closed_at := -1
## Кадр, когда показана находка: нажатие, которым её подобрали, окно не закрывает.
var _shown_at := -1
var _icon: TextureRect
var _name: Label
var _count: Label


## Это нажатие «взаимодействия» закрыло окно (или закроет): герою его не отдавать.
static func takes_interact() -> bool:
	if current == null or not current.blocks_interact:
		return false
	return current.visible or Engine.get_physics_frames() - current._closed_at <= 1


func _ready() -> void:
	current = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var frame := TextureRect.new()
	frame.texture = FRAME
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.3
	frame.anchor_bottom = 0.3
	frame.offset_left = -FRAME_SIZE.x * 0.5
	frame.offset_right = FRAME_SIZE.x * 0.5
	frame.offset_top = -FRAME_SIZE.y * 0.5
	frame.offset_bottom = FRAME_SIZE.y * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var row := HBoxContainer.new()
	row.position = Vector2(0, 64)
	row.size = Vector2(FRAME_SIZE.x, 92)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 36)
	_name.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	row.add_child(_name)
	_count = Label.new()
	_count.custom_minimum_size.x = 60
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_font_size_override("font_size", 28)
	_count.add_theme_color_override("font_color", Color(0.73, 0.69, 0.65))
	row.add_child(_count)
	var ok := Label.new()
	ok.text = "[E]  ОК"
	ok.position = Vector2(0, 222)
	ok.size = Vector2(FRAME_SIZE.x, 30)
	ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.add_theme_font_size_override("font_size", 21)
	ok.add_theme_color_override("font_color", Color(0.89, 0.88, 0.85))
	frame.add_child(ok)


## Находка: в очередь; окно показывает по одной. Неизвестное интерфейсу (флаги) не показываем.
func show_item(id: StringName) -> void:
	if not _known(id):
		return
	queue.append(id)
	if not visible:
		_next()


func _known(id: StringName) -> bool:
	return ItemCatalog.ITEMS.has(id) or Facet.by_id(id) != null \
		or ResourceLoader.exists("res://data/weapons/%s.tres" % id)


func _next() -> void:
	if queue.is_empty():
		visible = false
		shown = &""
		return
	shown = queue.pop_front()
	_icon.texture = ItemCatalog.icon(shown)
	_name.text = ItemCatalog.display_name(shown)
	var count := GameState.item_count(shown)
	_count.text = str(count) if count > 1 else ""
	_left = SHOW_TIME
	_shown_at = Engine.get_physics_frames()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)


## Закрыть показанную находку; в очереди есть ещё — показать следующую.
func dismiss() -> void:
	if not visible:
		return
	_closed_at = Engine.get_physics_frames()
	_next()


func _physics_process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	var pressed := Input.is_action_just_pressed("interact") and Engine.get_physics_frames() != _shown_at
	if _left <= 0.0 or (blocks_interact and pressed):
		dismiss()
