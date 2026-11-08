class_name Hud
extends Control
## Интерфейс (§8.12): слева вверху медальон с зельем, полосы здоровья и выносливости в металлической
## раме, под ними баффы и дебаффы; слева внизу крестовина расходников из четырёх ромбов;
## справа вверху отзвуки, справа внизу оружие обоих наборов.
## Стекло и металл тускнеют в тёмной комнате и бликуют на светлой. Ещё — подсказка взаимодействия,
## окно находки (ItemPopup), экран смерти и затемнение.
## Отладка возраста (§1.3): F1/F2 меняют стартовый возраст на лету, F3 показывает числа тела.

## Через сколько секунд после смерти появляется «ТЫ ПОГИБ»: тело успевает упасть.
const DEATH_LABEL_DELAY := 0.95
## Тон под надписью звучит без места в мире — убавлен до уровня звуков комнаты.
const DEATH_STING_DB := -9.0
const CARD_TIME := 1.9
## Высота чёрных полос катсцены.
const CINEMA_BAR := 90.0
## Как часто HUD смотрит на свет комнаты и оружие в руках.
const POLL_TIME := 0.25
## Свет комнаты → яркость HUD: тёмная комната не гасит интерфейс совсем.
const LIGHT_GAIN := 3.0
const DIM_MIN := 0.62
const MARK := preload("res://assets/ui/hud/mark.svg")
const MARK_EMPTY := preload("res://assets/ui/hud/mark_empty.svg")
const MEDALLION := preload("res://assets/ui/hud/painted/medallion.png")
## Нарисованные рамка значка эффекта и треугольники бафф/дебафф (лист автора, tools/ui/cut_hud_sheet.py).
const BUFF_FRAME := preload("res://assets/ui/hud/painted/buff_frame.png")
const BUFF_UP := preload("res://assets/ui/hud/painted/tri_up_green.png")
const DEBUFF_DOWN := preload("res://assets/ui/hud/painted/tri_down_red.png")
## Длина полос растёт с максимумом, как в Souls (§8.12): с начала короче, с уровнем длиннее.
## Ширина проёма на экране: в начале, за единицу сверх начального максимума и потолок (дальше рамы
## упёрлись бы в отзвуки справа). Здоровье 70 → ~284 (все ступени) — 420 → 1000.
const HP_WIDTH_START := 420.0
const HP_WIDTH_PER_POINT := 2.7
const HP_WIDTH_MAX := 1000.0
const STAMINA_WIDTH_START := 280.0
const STAMINA_WIDTH_PER_POINT := 2.7
const STAMINA_WIDTH_MAX := 700.0
## Ромб ячейки расходника (заглушка из референса автора, tools/ui/cut_quick_cross.py).
const QUICK_CELL := preload("res://assets/ui/hud/painted/quick_cell.png")
## Крестовина: размер ромба и сдвиг ячеек от середины — по референсу ромбы заходят друг на друга.
const QUICK_SIZE := 96.0
const QUICK_STEP := Vector2(55.0, 47.0)
## Ячейки по порядку GameState.quick_slots: верх, лево, право, низ. Рисуются снизу вверх.
const QUICK_AT: Array[Vector2] = [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
const QUICK_DRAW_ORDER: Array[int] = [3, 1, 2, 0]
## Кончились — значок тускнеет, ячейка остаётся на месте.
const QUICK_EMPTY_ALPHA := 0.32

@export var player_path: NodePath

var _player: Player
var _echoes_shown := 0
var boss_bar: ProgressBar
var _boss_box: Control
var _cards_running := false
var _cards_skipped := false
var _say_label: Label
var _say_tween: Tween
var _notice_label: Label
var _notice_tween: Tween
var _bars: Array[ColorRect] = []
var popup: ItemPopup
## Свет комнаты 0…1: от него тускнеют медальоны и бежит блик по зелью.
var light := 0.5
var _poll := 0.0
var _weapon_key := ""
var _weapon_icon: TextureRect
var _weapon_name: Label
var _weapon_glass: Label
var _weapon_marks: HBoxContainer
var _bow_line: Label
var _bow_icon: TextureRect
## Стрелы у лука (§6.2): значок и число активного гнезда, рядом тусклый значок другого.
var _arrow_icon: TextureRect
var _arrow_count: Label
var _arrow_other: TextureRect
var _second_line: Label
var _metal: Array[CanvasItem] = []
var _quick_icons: Array[TextureRect] = []
## Максимумы, под которые сейчас подогнана длина полос; -1 — ещё не подгоняли.
var _health_max_shown := -1.0
var _stamina_max_shown := -1.0
var _quick_counts: Array[Label] = []

@onready var health_bar: TextureProgressBar = %HealthBar
@onready var stamina_bar: TextureProgressBar = %StaminaBar
@onready var health_frame: BarFrame = $TopLeft/HealthFrame
@onready var stamina_frame: BarFrame = $TopLeft/StaminaFrame
@onready var currency_label: Label = %Currency
@onready var flasks_label: Label = %Flasks
@onready var flask_icon: TextureRect = %Flask
@onready var effects_row: HBoxContainer = %Effects
@onready var reality_label: Label = %Reality
@onready var age_label: Label = %AgeInfo
@onready var prompt_label: Label = %Prompt
@onready var death_label: Label = %DeathLabel
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	_player = get_node(player_path)
	_player.health_changed.connect(_on_health_changed)
	_player.stamina_changed.connect(_on_stamina_changed)
	_player.stats.changed.connect(_refresh_age)
	Events.echoes_changed.connect(_on_echoes_changed)
	_player.flasks_changed.connect(_on_flasks_changed)
	Events.reality_changed.connect(_on_reality_changed)
	Events.interact_prompt_changed.connect(_on_prompt_changed)
	Events.player_died.connect(_on_player_died)
	popup = ItemPopup.new()
	add_child(popup)
	Events.item_found.connect(popup.show_item)
	_player.effects_changed.connect(_refresh_effects)
	Events.message.connect(toast)
	Events.boss_engaged.connect(_on_boss_engaged)
	Events.mastery_step_reached.connect(_on_mastery_step)
	_say_label = _make_line(Control.PRESET_CENTER_BOTTOM, 170, Control.GROW_DIRECTION_BEGIN)
	_notice_label = _make_line(Control.PRESET_CENTER_TOP, 110, Control.GROW_DIRECTION_END)
	death_label.visible = false
	prompt_label.text = ""
	fade.color.a = 1.0
	_on_echoes_changed(GameState.echoes)
	_on_flasks_changed(_player.flasks, _player.max_flasks())
	_on_health_changed(_player.health.current, _player.health.max_health)
	_on_stamina_changed(_player.stamina, _player.stats.max_stamina)
	_player.stamina_short.connect(_flash_stamina)
	currency_label.pivot_offset = Vector2(320.0, 18.0)
	_build_weapon_panel()
	_build_quick_cross()
	Events.quick_items_changed.connect(_refresh_quick)
	for path in ["TopLeft/Medallion", "TopLeft/Badge", "TopLeft/HealthFrame", "TopLeft/StaminaFrame"]:
		_metal.append(get_node(path))
	_refresh_age()
	_refresh_effects()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_TIME
	_refresh_light()
	_refresh_weapon()


func _unhandled_input(event: InputEvent) -> void:
	if _cards_running and event.is_pressed() and not event.is_echo():
		_cards_skipped = true
		return
	if event.is_action_pressed("debug_age_down"):
		_player.stats.age -= 1
	elif event.is_action_pressed("debug_age_up"):
		_player.stats.age += 1
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		age_label.visible = not age_label.visible


func fade_to(alpha: float, duration: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, duration)
	return tween.finished


func hide_death() -> void:
	death_label.visible = false


func _on_health_changed(current: float, maximum: float) -> void:
	if maximum != _health_max_shown:
		_health_max_shown = maximum
		var extra := maximum - _player.stats.base_health
		_fit_bar(health_frame, health_bar, minf(HP_WIDTH_START + extra * HP_WIDTH_PER_POINT, HP_WIDTH_MAX))
	health_bar.max_value = maximum
	health_bar.value = current


func _on_stamina_changed(current: float, maximum: float) -> void:
	if maximum != _stamina_max_shown:
		_stamina_max_shown = maximum
		var extra := maximum - _player.stats.base_stamina
		_fit_bar(stamina_frame, stamina_bar, minf(STAMINA_WIDTH_START + extra * STAMINA_WIDTH_PER_POINT, STAMINA_WIDTH_MAX))
	stamina_bar.max_value = maximum
	stamina_bar.value = current


## Рама вытягивается под проём, полоса ложится в проём целиком — от торца до острия наконечника:
## полная полоса заполняет раму до конца.
func _fit_bar(frame: BarFrame, bar: TextureProgressBar, width: float) -> void:
	frame.opening_width = width
	var opening := frame.opening_rect()
	bar.position.x = frame.position.x + opening.x
	bar.size.x = opening.y


## Отзвуки: прибавились — счётчик коротко вспыхивает.
func _on_echoes_changed(total: int) -> void:
	var grew := total > _echoes_shown
	_echoes_shown = total
	currency_label.text = _grouped(total)
	if grew:
		var tween := create_tween()
		tween.tween_property(currency_label, "scale", Vector2(1.25, 1.25), 0.08)
		tween.tween_property(currency_label, "scale", Vector2.ONE, 0.2)


## Новая ступень мастерства оружия в руке.
func _on_mastery_step(type: StringName, step: int) -> void:
	var weapon := _player.weapon
	if weapon and weapon.type == type and step <= weapon.step_names.size():
		notice("Мастерство: %s" % weapon.step_names[step - 1])


## Свет комнаты: окружение и солнце текущего мира; комната может задать его сама (Room.hud_light).
func _refresh_light() -> void:
	var room := get_tree().get_first_node_in_group(&"room") as Room
	light = room.hud_brightness(LIGHT_GAIN) if room else 0.5
	var dim := lerpf(DIM_MIN, 1.0, light)
	for item in _metal:
		item.self_modulate = Color(dim, dim, dim)
	(flask_icon.material as ShaderMaterial).set_shader_parameter(&"light", light)


## Баффы и дебаффы под полосами: значок и треугольник — вверх зелёный, вниз красный.
func _refresh_effects() -> void:
	for child in effects_row.get_children():
		effects_row.remove_child(child)
		child.queue_free()
	for id: StringName in _player.effects:
		var effect := StatusEffect.by_id(id)
		var column := VBoxContainer.new()
		column.name = String(id)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(52, 52)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.tooltip_text = effect.display_name if effect else String(id)
		column.add_child(cell)
		var icon := TextureRect.new()
		icon.texture = ItemCatalog.icon(id)
		# Сначала режим растяжения, потом размер: иначе TextureRect берёт размер текстуры.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(7, 7)
		icon.size = Vector2(38, 38)
		cell.add_child(icon)
		var frame := TextureRect.new()
		frame.texture = BUFF_FRAME
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.size = Vector2(52, 52)
		cell.add_child(frame)
		var good := effect != null and effect.positive
		var arrow := TextureRect.new()
		arrow.texture = BUFF_UP if good else DEBUFF_DOWN
		arrow.custom_minimum_size = Vector2(18, 14)
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(arrow)
		effects_row.add_child(column)


## Оружие справа внизу: медальон со значком, имя, закалка, ступени мастерства; лук; набор II.
func _build_weapon_panel() -> void:
	var panel := HBoxContainer.new()
	panel.name = "WeaponPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 36)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.alignment = BoxContainer.ALIGNMENT_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_END
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(text)
	_second_line = _panel_label(text, 16, Color(0.72, 0.74, 0.76, 0.75))
	_second_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bow_row := HBoxContainer.new()
	bow_row.alignment = BoxContainer.ALIGNMENT_END
	text.add_child(bow_row)
	_arrow_other = TextureRect.new()
	_arrow_other.custom_minimum_size = Vector2(22, 22)
	_arrow_other.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow_other.size_flags_vertical = Control.SIZE_SHRINK_END
	_arrow_other.modulate = Color(1, 1, 1, 0.45)
	bow_row.add_child(_arrow_other)
	_arrow_icon = TextureRect.new()
	_arrow_icon.custom_minimum_size = Vector2(32, 32)
	_arrow_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bow_row.add_child(_arrow_icon)
	_arrow_count = _panel_label(bow_row, 16, Color(0.85, 0.82, 0.74))
	_bow_icon = TextureRect.new()
	_bow_icon.custom_minimum_size = Vector2(38, 38)
	_bow_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bow_row.add_child(_bow_icon)
	_bow_line = _panel_label(bow_row, 17, Color(0.73, 0.76, 0.8))
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	text.add_child(name_row)
	_weapon_name = _panel_label(name_row, 28, Color(0.93, 0.95, 0.97))
	_weapon_glass = _panel_label(name_row, 22, Color(0.79, 0.73, 0.61))
	_weapon_marks = HBoxContainer.new()
	_weapon_marks.alignment = BoxContainer.ALIGNMENT_END
	_weapon_marks.add_theme_constant_override("separation", 4)
	text.add_child(_weapon_marks)
	var medal := TextureRect.new()
	medal.texture = MEDALLION
	medal.custom_minimum_size = Vector2(128, 128)
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(medal)
	_metal.append(medal)
	_weapon_icon = TextureRect.new()
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.position = Vector2(36, 37)
	_weapon_icon.size = Vector2(56, 56)
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.add_child(_weapon_icon)


func _panel_label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	parent.add_child(label)
	return label


func _refresh_weapon() -> void:
	var weapon := _player.weapon
	var key := "%s|%d|%d|%s|%s|%s" % [weapon.id if weapon else &"", GameState.glass_level(weapon.id) if weapon else 0,
		GameState.mastery_step(weapon.type) if weapon else 0, GameState.bow_id if GameState.has_flag(&"has_bow") else &"",
		GameState.second_weapon_id, _arrows_key()]
	if key == _weapon_key:
		return
	_weapon_key = key
	(_weapon_icon.get_parent() as Control).visible = weapon != null
	_weapon_name.text = weapon.display_name if weapon else ""
	var glass := GameState.glass_level(weapon.id) if weapon else 0
	_weapon_glass.text = "+%d" % glass if glass > 0 else ""
	_weapon_icon.texture = ItemCatalog.icon(weapon.id) if weapon else null
	for child in _weapon_marks.get_children():
		_weapon_marks.remove_child(child)
		child.queue_free()
	if weapon:
		var step := GameState.mastery_step(weapon.type)
		for i in weapon.step_names.size():
			var mark := TextureRect.new()
			mark.texture = MARK if i < step else MARK_EMPTY
			mark.custom_minimum_size = Vector2(11, 15)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_weapon_marks.add_child(mark)
	var bow_id := GameState.bow_id if GameState.bow_id != &"" else &"has_bow"
	var has_bow := GameState.has_flag(&"has_bow")
	_bow_icon.visible = has_bow
	_bow_line.visible = has_bow
	_bow_icon.texture = ItemCatalog.icon(bow_id)
	_bow_line.text = ItemCatalog.display_name(bow_id).to_lower()
	_refresh_arrows(has_bow)
	var second := GameState.second_weapon_id
	_second_line.visible = second != &""
	_second_line.text = "II  %s" % ItemCatalog.display_name(second) if second != &"" else ""


## Что сейчас в гнёздах стрел: панель перерисовывается, когда это меняется.
func _arrows_key() -> String:
	var counts := []
	for id: StringName in GameState.arrow_slots:
		counts.append("%s:%d" % [id, GameState.item_count(id)])
	return "%d|%s" % [GameState.active_arrow, ",".join(counts)]


## Значок активных стрел с числом (обычные — без числа) и тусклый значок другого гнезда.
func _refresh_arrows(has_bow: bool) -> void:
	var active := GameState.current_arrow()
	var slot_other: StringName = GameState.arrow_slots[(GameState.active_arrow + 1) % GameState.ARROW_SLOTS]
	var other := slot_other if GameState.item_count(slot_other) > 0 else &""
	_arrow_icon.visible = has_bow
	_arrow_count.visible = has_bow and active != &""
	_arrow_other.visible = has_bow and other != active
	_arrow_icon.texture = ItemCatalog.icon(active if active != &"" else ItemCatalog.ARROW)
	_arrow_count.text = str(GameState.item_count(active)) if active != &"" else ""
	_arrow_other.texture = ItemCatalog.icon(other if other != &"" else ItemCatalog.ARROW)


## Крестовина расходников (§8.12) слева внизу: четыре ромба, в каждом значок и число.
## Клавиши 1–4 — верх, лево, право, низ; на геймпаде — держать правый курок и нажать крестовину.
func _build_quick_cross() -> void:
	var cross := Control.new()
	cross.name = "QuickCross"
	var area := Vector2(QUICK_SIZE, QUICK_SIZE) + QUICK_STEP * 2.0
	cross.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cross.offset_left = 30.0
	cross.offset_right = 30.0 + area.x
	cross.offset_bottom = -64.0
	cross.offset_top = -64.0 - area.y
	cross.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)
	_quick_icons.resize(GameState.QUICK_SLOTS)
	_quick_counts.resize(GameState.QUICK_SLOTS)
	for slot in QUICK_DRAW_ORDER:
		var cell := Control.new()
		cell.name = "Slot%d" % (slot + 1)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.position = area * 0.5 + QUICK_AT[slot] * QUICK_STEP - Vector2(QUICK_SIZE, QUICK_SIZE) * 0.5
		cell.size = Vector2(QUICK_SIZE, QUICK_SIZE)
		cross.add_child(cell)
		var frame := TextureRect.new()
		frame.texture = QUICK_CELL
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.size = cell.size
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(frame)
		_metal.append(frame)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = cell.size * 0.5
		icon.position = cell.size * 0.25
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		_quick_icons[slot] = icon
		var count := _panel_label(cell, 22, Color(0.93, 0.92, 0.88))
		count.position = cell.size * Vector2(0.56, 0.5)
		_quick_counts[slot] = count
	_refresh_quick()


func _refresh_quick() -> void:
	for slot in GameState.QUICK_SLOTS:
		var id := GameState.quick_item(slot)
		var icon := _quick_icons[slot]
		var count := _quick_counts[slot]
		icon.texture = ItemCatalog.icon(id) if id != &"" else null
		var left := GameState.item_count(id) if id != &"" else 0
		icon.modulate.a = 1.0 if left > 0 else QUICK_EMPTY_ALPHA
		count.text = str(left) if id != &"" else ""
		count.modulate.a = 1.0 if left > 0 else 0.5


## У осколка меню закрывает экран: полосы, оружие и подсказки управления прячутся.
func show_gameplay(on: bool) -> void:
	for path in ["TopLeft", "TopRight", "WeaponPanel", "QuickCross", "Controls"]:
		(get_node(path) as CanvasItem).visible = on


## 1240 → «1 240».
static func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## Здоровье босса внизу экрана, пока он жив и комната та же.
func _on_boss_engaged(boss: Dummy) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 90)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.custom_minimum_size = Vector2(760, 0)
	var title := Label.new()
	title.text = boss.boss_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 14
	bar.show_percentage = false
	bar.max_value = boss.health.max_health
	bar.value = boss.health.current
	bar.modulate = Color(0.85, 0.3, 0.2)
	box.add_child(bar)
	add_child(box)
	boss_bar = bar
	_boss_box = box
	boss.health.changed.connect(_on_boss_health)
	boss.health.died.connect(_close_boss_bar)
	boss.tree_exiting.connect(_close_boss_bar)


func _on_boss_health(current: float, _maximum: float) -> void:
	if is_instance_valid(boss_bar):
		boss_bar.value = current


func _close_boss_bar() -> void:
	if is_instance_valid(_boss_box):
		_boss_box.queue_free()
	_boss_box = null


## Заставка: чёрный экран, строки по очереди. Любая кнопка её пропускает.
func play_cards(lines: PackedStringArray, each := CARD_TIME) -> void:
	var veil := ColorRect.new()
	veil.color = Color.BLACK
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	veil.add_child(label)
	_cards_skipped = false
	_cards_running = true
	for line in lines:
		label.text = line
		label.modulate.a = 0.0
		create_tween().tween_property(label, "modulate:a", 1.0, 0.35)
		var left := each
		while left > 0.0 and not _cards_skipped:
			left -= get_process_delta_time()
			await get_tree().process_frame
		if _cards_skipped:
			break
	_cards_running = false
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 0.0, 0.8)
	tween.tween_callback(veil.queue_free)
	await tween.finished


## Реплика, записка или событие внизу экрана. Одна строка: новая сменяет прежнюю, а не ложится поверх.
func toast(text: String) -> void:
	_say_tween = _show_line(_say_label, _say_tween, text)


## Находка или новая ступень мастерства — своя строка вверху, чтобы реплика её не стёрла.
func notice(text: String) -> void:
	_notice_tween = _show_line(_notice_label, _notice_tween, text)


func _make_line(preset: Control.LayoutPreset, margin: int, grow: Control.GrowDirection) -> Label:
	var label := Label.new()
	label.modulate = Color(0.72, 0.86, 1.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = grow
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Показать текст в строке: прежний гаснет мгновенно, новый держится тем дольше, чем он длиннее.
func _show_line(label: Label, old: Tween, text: String) -> Tween:
	if old:
		old.kill()
	label.text = text
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(clampf(1.6 + text.length() * 0.045, 2.5, 7.0))
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	return tween


## Катсцена: сверху и снизу наезжают чёрные полосы, полоса босса и подсказка прячутся.
func cinematic(on: bool, time := 0.5) -> void:
	if _bars.is_empty():
		for preset in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
			var bar := ColorRect.new()
			bar.color = Color.BLACK
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.set_anchors_and_offsets_preset(preset)
			bar.grow_vertical = Control.GROW_DIRECTION_END if preset == Control.PRESET_TOP_WIDE else Control.GROW_DIRECTION_BEGIN
			add_child(bar)
			_bars.append(bar)
	if is_instance_valid(_boss_box):
		_boss_box.visible = not on
	prompt_label.visible = not on
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for bar: ColorRect in _bars:
		tween.tween_property(bar, "custom_minimum_size:y", CINEMA_BAR if on else 0.0, time)


## Не хватило выносливости: полоса коротко вспыхивает красным.
func _flash_stamina() -> void:
	var tween := create_tween()
	tween.tween_property(stamina_bar, "modulate", Color(1.0, 0.3, 0.25), 0.06)
	tween.tween_property(stamina_bar, "modulate", Color.WHITE, 0.35)


func _on_flasks_changed(current: int, maximum: int) -> void:
	flasks_label.text = str(current)
	flask_icon.modulate = Color(1, 1, 1, 1.0 if current > 0 else 0.35)


func _on_reality_changed(reality: StringName) -> void:
	reality_label.text = "Реальность: обычная" if reality == &"normal" else "Реальность: отражение"


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = "[E]  %s" % text if text != "" else ""


## Надпись — когда тело уже упало; под ней — приглушённый стеклянный тон.
func _on_player_died() -> void:
	await get_tree().create_timer(DEATH_LABEL_DELAY).timeout
	if _player.is_dead():
		death_label.visible = true
		Sfx.play_ui(&"death_sting", DEATH_STING_DB)


func _refresh_age() -> void:
	var s := _player.stats
	age_label.text = "\n".join([
		"Возраст: %.2f · уровень %d   (F1 −  /  F2 + — стартовый)" % [s.current_age, s.level],
		"Скорость %.2f · прыжок %.2f" % [s.move_speed, s.jump_velocity],
		"Перекат: неуязвимость %.2f с · урон меча %.1f" % [s.roll_iframes, s.sword_damage],
	])
