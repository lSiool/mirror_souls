class_name Hud
extends Control
## Интерфейс прототипа: здоровье, выносливость, отзвуки, зелье, текущая реальность,
## подсказка взаимодействия, экран смерти и затемнение.
## Отладка возраста (§1.3): F1/F2 меняют стартовый возраст на лету.

## Через сколько секунд после смерти появляется «ТЫ ПОГИБ»: тело успевает упасть.
const DEATH_LABEL_DELAY := 0.95
## Тон под надписью звучит без места в мире — убавлен до уровня звуков комнаты.
const DEATH_STING_DB := -9.0
const CARD_TIME := 1.9
## Высота чёрных полос катсцены.
const CINEMA_BAR := 90.0
const ITEM_NAMES := {&"clear_glass": "чистое стекло", &"facet_slot": "слот для граней", &"tempered_glass": "закалённое стекло",
	&"bow_hunter": "охотничий лук", &"bow_guard": "лук стражи", &"has_bow": "лук",
	&"flask_vessel": "второй глоток зелья", &"flask_potency": "крепкое зелье Травницы",
	&"stick": "палка", &"sword": "меч", &"bow": "лук", &"boss_smith_echo": "отзвук Безмолвного Кузнеца"}

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

@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var currency_label: Label = %Currency
@onready var flasks_label: Label = %Flasks
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
	Events.item_found.connect(_on_item_found)
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
	_player.stamina_short.connect(_flash_stamina)
	currency_label.pivot_offset = Vector2(0.0, 12.0)
	_refresh_age()


func _unhandled_input(event: InputEvent) -> void:
	if _cards_running and event.is_pressed() and not event.is_echo():
		_cards_skipped = true
		return
	if event.is_action_pressed("debug_age_down"):
		_player.stats.age -= 1
	elif event.is_action_pressed("debug_age_up"):
		_player.stats.age += 1


func fade_to(alpha: float, duration: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, duration)
	return tween.finished


func hide_death() -> void:
	death_label.visible = false


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


## Отзвуки: прибавились — счётчик коротко вспыхивает.
func _on_echoes_changed(total: int) -> void:
	var grew := total > _echoes_shown
	_echoes_shown = total
	currency_label.text = "Отзвуки: %d" % total
	if grew:
		var tween := create_tween()
		tween.tween_property(currency_label, "scale", Vector2(1.25, 1.25), 0.08)
		tween.tween_property(currency_label, "scale", Vector2.ONE, 0.2)


## Новая ступень мастерства оружия в руке.
func _on_mastery_step(type: StringName, step: int) -> void:
	var weapon := _player.weapon
	if weapon and weapon.type == type and step <= weapon.step_names.size():
		notice("Мастерство: %s" % weapon.step_names[step - 1])


## Найден редкий предмет: название появляется над подсказкой и гаснет.
func _on_item_found(id: StringName) -> void:
	var facet := Facet.by_id(id)
	notice("Найдено: %s" % (facet.display_name if facet else ITEM_NAMES.get(id, String(id))))


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
	flasks_label.text = "Зелье: %s%s" % ["◆".repeat(current), "◇".repeat(maxi(maximum - current, 0))]


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
