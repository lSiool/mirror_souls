class_name LevelMenu
extends Control
## Меню у осколка (§8.6, §8.12) — как место благодати Elden Ring: корень — короткий список, каждый
## пункт — свой экран, «Назад» возвращает к списку. Справа в мире — отражение героя в осколке.
## «Поднять уровень»: как в Dark Souls, сначала набрать очки по характеристикам (одно очко — один
## уровень), потом «Подтвердить» и «Повысить уровень?». Рядом всегда видно «было → станет» и что
## возраст заберёт у тела. Чистое стекло освобождает очки, возраст при этом не меняется.
## «Грани» — надеть и снять; «Оружие» — наборы I и II, закалка, мастерство, приёмы; «Предметы».

signal closed
## Перенестись к главному осколку у часовни (хаб).
signal hub_requested

const CLEAR_GLASS: StringName = &"clear_glass"
const FACET_SLOT: StringName = &"facet_slot"
const TYPE_NAMES := {&"sword": "Меч", &"bow": "Лук", &"spear": "Копьё", &"axe": "Топор", &"hammer": "Молот"}

enum Page { ROOT, LEVEL, FACETS, WEAPON, ITEMS }
const PAGE_TITLES := {Page.LEVEL: "Поднять уровень", Page.FACETS: "Грани", Page.WEAPON: "Оружие", Page.ITEMS: "Предметы"}
const PARAMS := {
	PlayerStats.Param.VIGOR: ["Жизненная сила", "здоровье"],
	PlayerStats.Param.ENDURANCE: ["Стойкость", "выносливость, стойкость к удару"],
	PlayerStats.Param.VITALITY: ["Крепость", "вес снаряжения, защита"],
	PlayerStats.Param.STRENGTH: ["Сила", "силовое оружие"],
	PlayerStats.Param.DEXTERITY: ["Ловкость", "быстрое оружие, лук, добивания"],
	PlayerStats.Param.INTELLIGENCE: ["Интеллект", "стеклянная магия"],
	PlayerStats.Param.LUCK: ["Удача", "находки, кровотечение"],
}
const DEFENSE_NAMES := {&"physical": "Физическая", &"glass": "От стекла", &"fire": "От огня", &"cold": "От холода"}
const RESIST_NAMES := {&"bleed": "Кровотечение", &"blind": "Слепота", &"cold": "Холод", &"heat": "Жар"}
const ROLL_NAMES := ["лёгкий", "средний", "тяжёлый"]
## Название места у осколка в заголовке меню.
const PLACE_NAMES := {&"village_hut": "Хижина", &"village_street": "Улица", &"village_house": "Дом",
	&"village_square": "Площадь", &"chapel_yard": "Двор часовни", &"chapel": "Часовня",
	&"cemetery_gate": "Кладбищенские ворота", &"cemetery": "Кладбище", &"forest_wall": "Стена леса",
	&"fallen_giant": "Поваленный гигант", &"root_maze": "Корневой лабиринт", &"swamp": "Болото",
	&"cursed_village": "Мёртвая деревня", &"room_001": "Комната-прототип"}
const SCALING_SHOWN: Array[PlayerStats.Param] = [PlayerStats.Param.STRENGTH, PlayerStats.Param.DEXTERITY,
	PlayerStats.Param.INTELLIGENCE, PlayerStats.Param.LUCK]

const TEXT := Color(0.93, 0.94, 0.95)
const MUTED := Color(0.6, 0.63, 0.67)
const ACCENT := Color(0.72, 0.86, 1.0)
const BRONZE := Color(0.79, 0.73, 0.61)
const WARN := Color(0.88, 0.47, 0.42)
const DIVIDER := preload("res://assets/ui/hud/divider.svg")
const MARK := preload("res://assets/ui/hud/mark.svg")
const MARK_EMPTY := preload("res://assets/ui/hud/mark_empty.svg")
const BUTTON := preload("res://assets/ui/hud/button.svg")
const SECTION := preload("res://assets/ui/hud/section.svg")
const BUTTON_LIT := preload("res://assets/ui/hud/button_lit.svg")
const BUTTON_OFF := preload("res://assets/ui/hud/button_off.svg")

## Шрифт с засечками из системы, пока в проекте нет своего (OFL-шрифт — позже).
var _serif_font := _serif()
var is_open := false
## Можно ли отсюда перенестись к главному осколку: выставляет RoomManager перед open().
var hub_available := false
var reflection: ShardReflection
var _player: Player
var _animating := false
var _page := Page.ROOT
var _backdrop: TextureRect
## На страницах экран почти закрыт: мир за ними не мешает читать числа.
var _veil: ColorRect
var _caption: Label
var _title: Label
var _hint: Label
var _pages := {}
var _root_buttons: Array[Button] = []
var _hub: Button
var _leave: Button
var _status: Label
# Поднять уровень.
var _buttons := {}
var _minus := {}
var _values := {}
var _level_label: Label
var _hero_rows: VBoxContainer
var _defense_rows: VBoxContainer
var _body_rows: VBoxContainer
var _confirm: Button
var _respec: Button
## Набранные, но ещё не подтверждённые очки: характеристика → сколько.
var _pending := {}
var _dialog: PanelContainer
var _dialog_label: Label
var _yes: Button
# Грани.
var _slots_row: HBoxContainer
var _facet_grid: GridContainer
var _facet_name: Label
var _facet_text: Label
var _facet_picked: Facet
# Оружие.
var _set_rows: VBoxContainer
var _weapon_switch: Button
var _second_switch: Button
var _bow_switch: Button
var _card_icon: TextureRect
var _card_name: Label
var _card_info: Label
var _scaling_row: HBoxContainer
var _glass_row: HBoxContainer
var _temper: Button
var _temper_cost: Label
var _mastery_rows: VBoxContainer
var _moves_label: Label
# Предметы.
var _item_kind := ItemCatalog.Kind.WEAPON
var _item_tabs: HBoxContainer
var _item_grid: GridContainer
var _item_name: Label
var _item_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.025, 0.035, 0.93))
	gradient.set_color(1, Color(0.02, 0.025, 0.035, 0.0))
	gradient.add_point(0.42, Color(0.02, 0.025, 0.035, 0.8))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	_backdrop.texture = texture
	add_child(_backdrop)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.02, 0.025, 0.035, 0.78)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 96)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_caption = _label(column, "Осколок Главного Зеркала", 16, MUTED)
	_title = _label(column, "", 50, TEXT)
	_title.add_theme_font_override("font", _serif_font)
	var divider := TextureRect.new()
	divider.texture = DIVIDER
	divider.stretch_mode = TextureRect.STRETCH_KEEP
	column.add_child(divider)
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(pages)
	_build_root(_page_box(pages, Page.ROOT))
	_build_level(_page_box(pages, Page.LEVEL))
	_build_facets(_page_box(pages, Page.FACETS))
	_build_weapon(_page_box(pages, Page.WEAPON))
	_build_items(_page_box(pages, Page.ITEMS))
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 36)
	column.add_child(footer)
	_hint = _label(footer, "", 18, MUTED)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# «Подтвердить» — справа внизу, как в макете; видна только на «Поднять уровень».
	_confirm = _frame_button(footer, "Подтвердить", 30)
	_confirm.custom_minimum_size.x = 280
	_confirm.pressed.connect(confirm)
	_build_dialog()


func _page_box(parent: Control, page: Page) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	_pages[page] = box
	return box


# ---------------------------------------------------------------- Корень

func _build_root(page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation", 4)
	for entry in [[Page.LEVEL, "Поднять уровень"], [Page.FACETS, "Грани"], [Page.WEAPON, "Оружие"], [Page.ITEMS, "Предметы"]]:
		var button := _menu_button(page, entry[1], 34)
		button.pressed.connect(show_page.bind(entry[0]))
		_root_buttons.append(button)
	page.add_child(_spacer(14))
	_hub = _menu_button(page, "Перенестись к главному осколку", 28)
	_hub.pressed.connect(go_to_hub)
	_leave = _menu_button(page, "Отойти", 28)
	_leave.pressed.connect(close)
	for button: Button in _root_buttons + [_hub, _leave]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.custom_minimum_size.x = 560
	page.add_child(_spacer(30))
	var flavor := _label(page, "Отзвуки впитываются в отражение: оно станет старше — и ты вместе с ним.", 19, MUTED)
	flavor.custom_minimum_size.x = 520
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(push)
	_status = _label(page, "", 21, TEXT)


## Закрыть меню и перенестись к главному осколку.
func go_to_hub() -> void:
	if not hub_available or _animating:
		return
	close()
	hub_requested.emit()


# ---------------------------------------------------------------- Поднять уровень

func _build_level(page: VBoxContainer) -> void:
	_level_label = _label(page, "", 22, TEXT)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 56)
	page.add_child(row)
	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 500
	stats.add_theme_constant_override("separation", 4)
	row.add_child(stats)
	_section(stats, "Характеристики")
	for param: PlayerStats.Param in PlayerStats.PARAM_ORDER:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		stats.add_child(line)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", -4)
		line.add_child(names)
		_label(names, PARAMS[param][0], 25, TEXT)
		_label(names, PARAMS[param][1], 14, MUTED)
		var minus := _small_button(line, "−")
		minus.pressed.connect(func() -> void: unchoose(param))
		_minus[param] = minus
		var value := _label(line, "", 27, TEXT)
		value.custom_minimum_size.x = 52
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_values[param] = value
		var plus := _small_button(line, "+")
		plus.pressed.connect(func() -> void: choose(param))
		_buttons[param] = plus
	stats.add_child(_spacer(10))
	_respec = _menu_button(stats, "", 20)
	_respec.pressed.connect(use_clear_glass)
	var hero := VBoxContainer.new()
	hero.custom_minimum_size.x = 380
	row.add_child(hero)
	_section(hero, "Герой")
	_hero_rows = VBoxContainer.new()
	hero.add_child(_hero_rows)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 380
	row.add_child(side)
	_section(side, "Защита и сопротивления")
	_defense_rows = VBoxContainer.new()
	side.add_child(_defense_rows)
	side.add_child(_spacer(8))
	_section(side, "Тело и возраст")
	_body_rows = VBoxContainer.new()
	side.add_child(_body_rows)


func pending_total() -> int:
	var total := 0
	for count: int in _pending.values():
		total += count
	return total


## Сколько новых уровней в наборе: свободные очки (после чистого стекла) идут первыми и даром.
func pending_levels() -> int:
	return maxi(pending_total() - _player.stats.unspent, 0)


func pending_cost() -> int:
	return _player.stats.cost_of_levels(pending_levels())


## Набрать очко в характеристику — пока без траты: применится после подтверждения.
func choose(param: PlayerStats.Param) -> void:
	if _animating or not _can_add():
		return
	_pending[param] = _pending.get(param, 0) + 1
	_refresh()


func unchoose(param: PlayerStats.Param) -> void:
	if _animating or _pending.get(param, 0) <= 0:
		return
	_pending[param] -= 1
	if _pending[param] == 0:
		_pending.erase(param)
	_refresh()
	_focus_first()


## Хватит ли отзвуков, чтобы набрать ещё одно очко.
func _can_add() -> bool:
	var stats := _player.stats
	if pending_total() < stats.unspent:
		return true
	return GameState.echoes >= stats.cost_of_levels(pending_levels() + 1)


## «Подтвердить»: открыть окно «Повысить уровень?».
func confirm() -> void:
	if _animating or pending_total() == 0 or GameState.echoes < pending_cost():
		return
	var levels := pending_levels()
	var lines: Array[String] = []
	if levels > 0:
		lines.append("Повысить уровень?")
		lines.append("Уровень %d → %d" % [_player.stats.level, _player.stats.level + levels])
		lines.append("Отзвуки: %d → %d" % [GameState.echoes, GameState.echoes - pending_cost()])
	else:
		lines.append("Распределить свободные очки?")
	_dialog_label.text = "\n".join(lines)
	_dialog.visible = true
	_yes.grab_focus()


## Ответ в окне: «Да» применяет набранное, «Нет» возвращает к выбору, очки остаются набранными.
func answer(yes: bool) -> void:
	_dialog.visible = false
	if yes:
		await _apply()
	else:
		_focus_first()


## Свободные очки — сразу; новые уровни: отзвуки текут в отражение, оно на миг взрослеет
## на все прожитые годы, потом они переходят на героя.
func _apply() -> void:
	var stats := _player.stats
	var levels := pending_levels()
	var order: Array[PlayerStats.Param] = []
	for param: PlayerStats.Param in PlayerStats.PARAM_ORDER:
		for i in _pending.get(param, 0):
			order.append(param)
	_pending.clear()
	_animating = true
	if levels > 0:
		GameState.add_echoes(-stats.cost_of_levels(levels))
		_refresh()
		var from := _player.global_position + Vector3(0.0, 1.1, 0.0)
		var to := reflection.global_position + Vector3(0.0, 1.1, 0.0)
		for i in 5:
			EchoDrop.stream(reflection.get_parent(), from + Vector3(0.0, randf_range(-0.3, 0.3), 0.0), to, 0.4 + i * 0.05)
		await get_tree().create_timer(0.3).timeout
		Sfx.play(&"glass_glint", to, -6.0)
		await reflection.play_level_up(stats.age_at(stats.level + levels))
		Sfx.play(&"glass_glint", from, -6.0)
		HitSpark.spawn(reflection.get_parent(), from, EchoDrop.COLOR, 16)
		_player.body.flash(EchoDrop.COLOR)
	for param in order:
		if stats.unspent > 0:
			stats.spend_unspent(param)
		else:
			stats.level_up(param)
	_animating = false
	_refresh()
	_focus_first()


## Чистое стекло: очки снова свободны, годы остаются.
func use_clear_glass() -> void:
	if _animating or not GameState.take_item(CLEAR_GLASS):
		return
	_player.stats.respec()
	_refresh()
	_focus_first()


func _refresh_level() -> void:
	var stats := _player.stats
	var free := stats.unspent > pending_total()
	var levels := pending_levels()
	var shown := maxi(levels, 0 if free else 1)
	var next_age := stats.age_at(stats.level + maxi(levels, 0))
	if stats.unspent > 0:
		_level_label.text = "Свободных очков: %d — без отзвуков и без новых лет · отзвуки %s" % [
			stats.unspent - mini(pending_total(), stats.unspent), Hud._grouped(GameState.echoes)]
	else:
		_level_label.text = "Уровень %s · возраст %s · отзвуки %s · цена %d" % [_arrow_int(stats.level, stats.level + levels),
			_arrow_text(_age_text(stats.current_age), _age_text(next_age)), Hud._grouped(GameState.echoes), stats.cost_of_levels(shown)]
	var can_add := _can_add()
	for param: PlayerStats.Param in PlayerStats.PARAM_ORDER:
		var picked: int = _pending.get(param, 0)
		var value: Label = _values[param]
		value.text = str(_base_points(param) + stats.points_in(param) + picked)
		value.add_theme_color_override("font_color", ACCENT if picked > 0 else TEXT)
		(_buttons[param] as Button).disabled = _animating or not can_add
		(_minus[param] as Button).disabled = _animating or picked == 0
	var total := pending_total()
	_confirm.disabled = _animating or total == 0 or GameState.echoes < pending_cost()
	_respec.visible = GameState.item_count(CLEAR_GLASS) > 0
	_respec.text = "Чистое стекло (%d): перераспределить очки" % GameState.item_count(CLEAR_GLASS)
	_respec.disabled = _animating
	_fill_rows(_hero_rows, _hero_values())
	_fill_rows(_defense_rows, _defense_values())
	_fill_rows(_body_rows, _body_values(next_age))


## Показанное число характеристики: стартовое значение плюс вложенные очки (как в Souls — не с нуля).
func _base_points(_param: PlayerStats.Param) -> int:
	return 10


## [название, было, станет] — было: сейчас, станет: с набранными очками.
func _hero_values() -> Array:
	var stats := _player.stats
	var extra := _pending
	var rows := []
	rows.append(["Здоровье", "%.0f" % stats.max_health,
		"%.0f" % ((stats.base_health + stats.bonus_with(PlayerStats.Param.VIGOR, extra.get(PlayerStats.Param.VIGOR, 0))) * stats.facet_mult(&"max_health"))])
	rows.append(["Выносливость", "%.0f" % stats.max_stamina,
		"%.0f" % ((stats.base_stamina + stats.bonus_with(PlayerStats.Param.ENDURANCE, extra.get(PlayerStats.Param.ENDURANCE, 0))) * stats.facet_mult(&"max_stamina"))])
	rows.append(["Стойкость к удару", "%.0f" % stats.poise, "%.0f" % stats.poise_at(extra.get(PlayerStats.Param.ENDURANCE, 0))])
	var weight := _player.equip_weight()
	var load_after := stats.equip_load_at(extra.get(PlayerStats.Param.VITALITY, 0))
	rows.append(["Вес снаряжения", "%.1f / %.1f" % [weight, stats.equip_load], "%.1f / %.1f" % [weight, load_after]])
	rows.append(["Кувырок", ROLL_NAMES[stats.roll_class(weight, stats.equip_load)], ROLL_NAMES[stats.roll_class(weight, load_after)]])
	for set_index in 2:
		var id := GameState.weapon_id if set_index == 0 else GameState.second_weapon_id
		if id == &"":
			continue
		var weapon := WeaponData.by_id(id)
		var glass := GameState.glass_level(id)
		rows.append(["Урон %s: %s" % ["I" if set_index == 0 else "II", weapon.display_name],
			"%.0f" % _player.weapon_damage(weapon, glass), "%.0f" % _player.weapon_damage(weapon, glass, extra)])
	if GameState.has_flag(&"has_bow"):
		var dex := stats.bonus_with(PlayerStats.Param.DEXTERITY, extra.get(PlayerStats.Param.DEXTERITY, 0))
		var bow_after := stats.bow_damage_max * (1.0 + dex * WeaponData.grade_mult(PlayerStats.BOW_GRADE)) * stats.facet_mult(&"bow_damage") * GameState.bow_damage_mult()
		rows.append(["Урон лука", "%.0f" % (stats.bow_damage_max * stats.bow_damage_mult * GameState.bow_damage_mult()), "%.0f" % bow_after])
	rows.append(["Добивание", "×%.2f" % stats.critical_mult, "×%.2f" % stats.critical_at(extra.get(PlayerStats.Param.DEXTERITY, 0))])
	var intel := stats.points_in(PlayerStats.Param.INTELLIGENCE)
	var intel_after: int = intel + extra.get(PlayerStats.Param.INTELLIGENCE, 0)
	rows.append(["Стеклянная магия", "—" if intel == 0 else str(100 + 5 * intel), "—" if intel_after == 0 else str(100 + 5 * intel_after)])
	var luck_after: int = stats.points_in(PlayerStats.Param.LUCK) + extra.get(PlayerStats.Param.LUCK, 0)
	rows.append(["Находчивость", "%.0f" % stats.discovery, "%.0f" % (100.0 + stats.discovery_per_point * luck_after)])
	rows.append(["Кровотечение", "×%.2f" % stats.bleed_mult, "×%.2f" % (1.0 + stats.bleed_per_point * luck_after)])
	return rows


func _defense_values() -> Array:
	var stats := _player.stats
	var vit: int = _pending.get(PlayerStats.Param.VITALITY, 0)
	var rows := []
	for kind: StringName in PlayerStats.DEFENSES:
		rows.append([DEFENSE_NAMES[kind], "%.0f" % stats.defense(kind), "%.0f" % stats.defense(kind, vit)])
	for kind: StringName in PlayerStats.RESISTANCES:
		var value := "%.0f" % stats.resistance(kind)
		rows.append(["Сопротивление: %s" % RESIST_NAMES[kind].to_lower(), value, value])
	return rows


func _body_values(next_age: float) -> Array:
	var stats := _player.stats
	var now := stats.current_age
	return [
		["Возраст", _age_text(now), _age_text(next_age)],
		["Скорость бега", "%.2f" % stats.speed_at(now), "%.2f" % stats.speed_at(next_age)],
		["Прыжок", "%.2f м" % _jump_height(stats, now), "%.2f м" % _jump_height(stats, next_age)],
		["Неуязвимость кувырка", "%.3f с" % stats.iframes_at(now), "%.3f с" % stats.iframes_at(next_age)],
		["Подвижность", "%.1f" % stats.mobility_at(now), "%.1f" % stats.mobility_at(next_age)],
	]


## Строки «название · было → станет»: изменившееся — голубым.
func _fill_rows(box: VBoxContainer, rows: Array) -> void:
	while box.get_child_count() < rows.size():
		var line := HBoxContainer.new()
		var caption := _label(line, "", 18, Color(0.76, 0.79, 0.82))
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(line, "", 19, MUTED)
		box.add_child(line)
	for i in box.get_child_count():
		var line := box.get_child(i) as HBoxContainer
		line.visible = i < rows.size()
		if not line.visible:
			continue
		var row: Array = rows[i]
		(line.get_child(0) as Label).text = row[0]
		var value := line.get_child(1) as Label
		var changed: bool = row[1] != row[2]
		value.text = "%s → %s" % [row[1], row[2]] if changed else row[1]
		value.add_theme_color_override("font_color", ACCENT if changed else TEXT)


## Окно «Повысить уровень?» поверх меню.
func _build_dialog() -> void:
	_dialog = PanelContainer.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.045, 0.97)
	style.border_color = Color(0.66, 0.62, 0.55, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(28)
	_dialog.add_theme_stylebox_override("panel", style)
	_dialog.visible = false
	add_child(_dialog)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(400, 0)
	column.add_theme_constant_override("separation", 16)
	_dialog.add_child(column)
	_dialog_label = _label(column, "", 22, TEXT)
	_dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_yes = _menu_button(buttons, "Да", 24)
	_yes.custom_minimum_size = Vector2(120, 44)
	_yes.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_yes.pressed.connect(func() -> void: answer(true))
	var no := _menu_button(buttons, "Нет", 24)
	no.custom_minimum_size = Vector2(120, 44)
	no.alignment = HORIZONTAL_ALIGNMENT_CENTER
	no.pressed.connect(func() -> void: answer(false))


# ---------------------------------------------------------------- Грани

func _build_facets(page: VBoxContainer) -> void:
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	page.add_child(_slots_row)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 64)
	page.add_child(row)
	_facet_grid = GridContainer.new()
	_facet_grid.columns = 5
	_facet_grid.custom_minimum_size.x = 620
	_facet_grid.add_theme_constant_override("h_separation", 12)
	_facet_grid.add_theme_constant_override("v_separation", 12)
	row.add_child(_facet_grid)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 12)
	row.add_child(text)
	_facet_name = _label(text, "", 38, TEXT)
	_facet_text = _label(text, "", 21, Color(0.83, 0.85, 0.87))
	_facet_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facet_text.custom_minimum_size.x = 480
	var note := _label(text, "Пустые ячейки — грани, которых ещё нет. Новые слоты — за стеклом и в тайниках.", 16, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Слотов всего: стартовые и найденные.
func facet_slots() -> int:
	return PlayerStats.BASE_FACET_SLOTS + GameState.item_count(FACET_SLOT)


## Надеть или снять грань.
func toggle_facet(facet: Facet) -> void:
	if _player.stats.toggle_facet(facet, facet_slots()):
		Sfx.play(&"glass_glint", _player.global_position, -12.0)
	_facet_picked = facet
	_refresh()
	_focus_facet(facet)


func _refresh_facets() -> void:
	var stats := _player.stats
	for child in _slots_row.get_children():
		_slots_row.remove_child(child)
		child.queue_free()
	_label(_slots_row, "Слоты", 19, MUTED)
	for i in facet_slots():
		var mark := TextureRect.new()
		mark.texture = MARK if i < stats.facet_slots_used() else MARK_EMPTY
		mark.custom_minimum_size = Vector2(18, 25)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_slots_row.add_child(mark)
	_label(_slots_row, "%d / %d" % [stats.facet_slots_used(), facet_slots()], 22, TEXT)
	for child in _facet_grid.get_children():
		_facet_grid.remove_child(child)
		child.queue_free()
	var shown := 0
	for facet in Facet.catalog():
		if GameState.item_count(facet.id) <= 0:
			continue
		var worn := facet in stats.facets
		var button := _icon_button(_facet_grid, ItemCatalog.icon(facet.id), 108)
		button.name = String(facet.id)
		button.tooltip_text = facet.display_name
		button.modulate = Color(1, 1, 1) if worn else Color(0.62, 0.62, 0.62)
		button.disabled = not worn and stats.facet_slots_used() + facet.cost > facet_slots()
		if worn:
			var mark := TextureRect.new()
			mark.texture = MARK
			mark.position = Vector2(84, 6)
			mark.size = Vector2(16, 22)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(mark)
		button.pressed.connect(toggle_facet.bind(facet))
		button.focus_entered.connect(_describe.bind(facet))
		button.mouse_entered.connect(_describe.bind(facet))
		shown += 1
	for i in maxi(15 - shown, 0):
		var empty := _icon_button(_facet_grid, null, 108)
		empty.disabled = true
		empty.modulate = Color(1, 1, 1, 0.25)
	_describe(_facet_picked if _facet_picked else (Facet.by_id(_facet_grid.get_child(0).name) if shown > 0 else null))


## Описание грани; у возрастной — её сила сейчас.
func _describe(facet: Facet) -> void:
	if facet == null:
		_facet_name.text = ""
		_facet_text.text = "Граней пока нет."
		return
	_facet_picked = facet
	var worn := facet in _player.stats.facets
	_facet_name.text = facet.display_name
	var text := "%s\n\nСлотов: %d · %s" % [facet.description, facet.cost, "надета" if worn else "не надета"]
	if facet.age_curve != Facet.AgeCurve.NONE:
		text += "\nСила в %s лет: %d" % [_age_text(_player.stats.current_age), roundi(facet.strength(_player.stats.current_age) * 100.0)]
	_facet_text.text = text


func _focus_facet(facet: Facet) -> void:
	var button := _facet_grid.get_node_or_null(String(facet.id)) as Button
	if button and not button.disabled:
		button.grab_focus()
		_describe(facet)


# ---------------------------------------------------------------- Оружие

func _build_weapon(page: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 52)
	page.add_child(row)
	var sets := VBoxContainer.new()
	sets.custom_minimum_size.x = 300
	sets.add_theme_constant_override("separation", 6)
	row.add_child(sets)
	_section(sets, "С собой")
	_set_rows = VBoxContainer.new()
	sets.add_child(_set_rows)
	sets.add_child(_spacer(6))
	_weapon_switch = _menu_button(sets, "", 19)
	_weapon_switch.pressed.connect(switch_weapon)
	_second_switch = _menu_button(sets, "", 19)
	_second_switch.pressed.connect(switch_second)
	_bow_switch = _menu_button(sets, "", 19)
	_bow_switch.pressed.connect(switch_bow)
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 520
	card.add_theme_constant_override("separation", 14)
	row.add_child(card)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	card.add_child(head)
	_card_icon = TextureRect.new()
	_card_icon.custom_minimum_size = Vector2(120, 120)
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(_card_icon)
	var names := VBoxContainer.new()
	head.add_child(names)
	_card_name = _label(names, "", 42, TEXT)
	_card_info = _label(names, "", 19, MUTED)
	_section(card, "Скалирование")
	_scaling_row = HBoxContainer.new()
	_scaling_row.add_theme_constant_override("separation", 10)
	card.add_child(_scaling_row)
	_section(card, "Закалка стеклом")
	_glass_row = HBoxContainer.new()
	_glass_row.add_theme_constant_override("separation", 8)
	card.add_child(_glass_row)
	_temper = _frame_button(card, "", 24)
	_temper.pressed.connect(temper)
	_temper_cost = _label(card, "", 17, MUTED)
	var mastery := VBoxContainer.new()
	mastery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mastery.add_theme_constant_override("separation", 8)
	row.add_child(mastery)
	_mastery_rows = VBoxContainer.new()
	_mastery_rows.add_theme_constant_override("separation", 6)
	mastery.add_child(_mastery_rows)
	mastery.add_child(_spacer(6))
	_section(mastery, "Приёмы")
	_moves_label = _label(mastery, "", 18, Color(0.76, 0.79, 0.82))
	_moves_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Закалить оружие в руке.
func temper() -> void:
	if _player.weapon and GameState.temper(_player.weapon.id):
		Sfx.play(&"glass_glint", _player.global_position, -6.0)
	_refresh()
	_focus_first()


## Взять в руку другой лук, если их два.
func switch_bow() -> void:
	var bows := GameState.owned_bows()
	if bows.size() < 2:
		return
	GameState.bow_id = bows[(bows.find(GameState.bow_id) + 1) % bows.size()]
	Sfx.play(&"glass_glint", _player.global_position, -12.0)
	_refresh()


## Взять в руку (набор I) следующее оружие из того, что герой носит с собой.
func switch_weapon() -> void:
	var owned := GameState.owned_weapons()
	if owned.size() < 2:
		return
	var next: StringName = owned[(owned.find(GameState.weapon_id) + 1) % owned.size()]
	if next == GameState.second_weapon_id:
		GameState.second_weapon_id = GameState.weapon_id
	_player.equip(next)
	Sfx.play(&"glass_glint", _player.global_position, -12.0)
	_refresh()


## Набор II: следующее оружие из носимого (не то, что в наборе I), потом — пусто.
func switch_second() -> void:
	var choices: Array[StringName] = [&""]
	for id in GameState.owned_weapons():
		if id != GameState.weapon_id:
			choices.append(id)
	if choices.size() < 2:
		return
	GameState.second_weapon_id = choices[(choices.find(GameState.second_weapon_id) + 1) % choices.size()]
	Sfx.play(&"glass_glint", _player.global_position, -12.0)
	_refresh()


func _refresh_weapon() -> void:
	for child in _set_rows.get_children():
		_set_rows.remove_child(child)
		child.queue_free()
	var bow := ItemCatalog.display_name(GameState.bow_id) if GameState.bow_id != &"" else "лук"
	_set_line("I", _player.weapon.display_name if _player.weapon else "—", true)
	_set_line("II", ItemCatalog.display_name(GameState.second_weapon_id) if GameState.second_weapon_id != &"" else "пусто", false)
	if GameState.has_flag(&"has_bow"):
		_set_line("Лук", bow.to_lower(), false)
	if _player.has_shield():
		_set_line("Щит", "щит-гоплон", false)
	var owned := GameState.owned_weapons()
	_weapon_switch.visible = owned.size() >= 2
	if owned.size() >= 2:
		var next: StringName = owned[(owned.find(GameState.weapon_id) + 1) % owned.size()]
		_weapon_switch.text = "I: взять %s" % WeaponData.by_id(next).display_name.to_lower()
	_second_switch.visible = owned.size() >= 2
	_second_switch.text = "II: положить другое"
	var bows := GameState.owned_bows()
	_bow_switch.visible = bows.size() >= 2
	if bows.size() >= 2:
		var other: StringName = bows[(bows.find(GameState.bow_id) + 1) % bows.size()]
		_bow_switch.text = "Лук: взять %s" % GameState.BOWS[other][0]
	var weapon := _player.weapon
	_temper.visible = weapon != null
	for box in [_scaling_row, _glass_row, _mastery_rows]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	if weapon == null:
		_card_icon.texture = null
		_card_name.text = "В руках ничего нет"
		_card_info.text = ""
		_temper_cost.text = ""
		_moves_label.text = ""
		return
	var level := GameState.glass_level(weapon.id)
	_card_icon.texture = ItemCatalog.icon(weapon.id)
	_card_name.text = weapon.display_name + (" +%d" % level if level > 0 else "")
	_card_info.text = "%s · %s · вес %.1f · урон %.0f" % [TYPE_NAMES.get(weapon.type, String(weapon.type)),
		"двуручное" if weapon.two_handed else "одноручное", weapon.weight, _player._blade_damage()]
	for param in SCALING_SHOWN:
		var grade: String = weapon.scaling.get(PlayerStats.PARAM_IDS[param], "")
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 104
		_scaling_row.add_child(cell)
		var param_label := _label(cell, PARAMS[param][0], 15, MUTED)
		param_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var grade_label := _label(cell, grade if grade != "" else "—", 30, TEXT if grade != "" else MUTED)
		grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in GameState.GLASS_MATERIAL.size():
		var mark := TextureRect.new()
		mark.texture = MARK if i < level else MARK_EMPTY
		mark.custom_minimum_size = Vector2(24, 33)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glass_row.add_child(mark)
	# Как в Souls: при улучшении — сколько было и сколько станет, без процентов (§8.12).
	if level >= GameState.GLASS_MATERIAL.size():
		_temper.text = "Закалка завершена"
		_temper.disabled = true
		_temper_cost.text = ""
	else:
		_temper.text = "Закалить до +%d: урон %.0f → %.0f" % [level + 1, _player.weapon_damage(weapon, level), _player.weapon_damage(weapon, level + 1)]
		_temper.disabled = GameState.item_count(GameState.GLASS_ITEM) < GameState.GLASS_MATERIAL[level] or GameState.echoes < GameState.GLASS_ECHOES[level]
		_temper_cost.text = "Стекла %d из %d · отзвуков %d из %s" % [GameState.GLASS_MATERIAL[level], GameState.item_count(GameState.GLASS_ITEM),
			GameState.GLASS_ECHOES[level], Hud._grouped(GameState.echoes)]
	var step := GameState.mastery_step(weapon.type)
	var progress := GameState.mastery_progress(weapon.type)
	_section(_mastery_rows, "Мастерство: %s" % TYPE_NAMES.get(weapon.type, String(weapon.type)).to_lower())
	for i in weapon.step_names.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		_mastery_rows.add_child(line)
		var mark := TextureRect.new()
		mark.texture = MARK if i < step else MARK_EMPTY
		mark.custom_minimum_size = Vector2(14, 19)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.add_child(mark)
		var step_label := _label(line, "%d · %s" % [i + 1, weapon.step_names[i]], 19, TEXT if i < step else (Color(0.79, 0.81, 0.84) if i == step else MUTED))
		step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == step and progress != Vector2.ZERO:
			_label(line, "%.0f / %.0f" % [progress.x, progress.y], 16, MUTED)
	_moves_label.text = _moves_text(weapon, step)


## Приёмы оружия по его данным; закрытые ступенью — серым словом «ступень N».
func _moves_text(weapon: WeaponData, step: int) -> String:
	var lines: Array[String] = []
	var series: Array[String] = []
	for attack in weapon.combo_at(step):
		series.append(attack.display_name)
	lines.append("Серия: " + " → ".join(series))
	if weapon.charged:
		lines.append("Заряд: " + weapon.charged.display_name)
	if weapon.roll_attack:
		lines.append("После кувырка: " + weapon.roll_attack.display_name)
	if weapon.slide_attack:
		lines.append("Из скольжения: " + weapon.slide_attack.display_name)
	if weapon.air_attack:
		lines.append(("В прыжке: " + weapon.air_attack.display_name) + ("" if step >= WeaponData.STEP_AIR else " — ступень %d" % WeaponData.STEP_AIR))
	if weapon.counter:
		lines.append(("Контрудар: " + weapon.counter.display_name) + ("" if step >= WeaponData.STEP_COUNTER else " — ступень %d" % WeaponData.STEP_COUNTER))
	lines.append("Добивание и удар в спину")
	return "\n".join(lines)


func _set_line(tag: String, text: String, held: bool) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	_set_rows.add_child(line)
	var mark := _label(line, tag, 20, BRONZE)
	mark.custom_minimum_size.x = 44
	_label(line, text, 24 if held else 21, TEXT if held else Color(0.79, 0.81, 0.84))


# ---------------------------------------------------------------- Предметы

func _build_items(page: VBoxContainer) -> void:
	_item_tabs = HBoxContainer.new()
	_item_tabs.add_theme_constant_override("separation", 6)
	page.add_child(_item_tabs)
	for kind: ItemCatalog.Kind in ItemCatalog.KIND_NAMES:
		var tab := _menu_button(_item_tabs, ItemCatalog.KIND_NAMES[kind], 22)
		tab.toggle_mode = true
		tab.pressed.connect(func() -> void:
			_item_kind = kind
			_refresh())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 64)
	page.add_child(row)
	_item_grid = GridContainer.new()
	_item_grid.columns = 5
	_item_grid.custom_minimum_size.x = 620
	_item_grid.add_theme_constant_override("h_separation", 12)
	_item_grid.add_theme_constant_override("v_separation", 12)
	row.add_child(_item_grid)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 12)
	row.add_child(text)
	_item_name = _label(text, "", 38, TEXT)
	_item_text = _label(text, "", 21, Color(0.83, 0.85, 0.87))
	_item_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_text.custom_minimum_size.x = 480


## Что в разделе: оружие — носимое, щит и луки; расходники — зелье; остальное — по каталогу.
func _items_of(kind: ItemCatalog.Kind) -> Array[StringName]:
	var result: Array[StringName] = []
	if kind == ItemCatalog.Kind.WEAPON:
		result.append_array(GameState.owned_weapons())
		if _player.has_shield():
			result.append(GameState.SHIELD_ITEM)
		result.append_array(GameState.owned_bows())
		return result
	if kind == ItemCatalog.Kind.CONSUMABLE:
		result.append(ItemCatalog.FLASK)
		return result
	return ItemCatalog.owned(kind)


func _refresh_items() -> void:
	for i in _item_tabs.get_child_count():
		(_item_tabs.get_child(i) as Button).button_pressed = i == _item_kind
	for child in _item_grid.get_children():
		_item_grid.remove_child(child)
		child.queue_free()
	var list := _items_of(_item_kind)
	for id in list:
		var button := _icon_button(_item_grid, ItemCatalog.icon(id), 108)
		button.tooltip_text = ItemCatalog.display_name(id)
		var count := _player.max_flasks() if id == ItemCatalog.FLASK else GameState.item_count(id)
		if count > 1:
			var badge := _label(button, str(count), 22, TEXT)
			badge.position = Vector2(74, 74)
		button.focus_entered.connect(_describe_item.bind(id))
		button.mouse_entered.connect(_describe_item.bind(id))
	if list.is_empty():
		_item_name.text = ""
		_item_text.text = "Пока пусто. Записки, письма и надписи из мира будут здесь — их можно перечитать." \
			if _item_kind == ItemCatalog.Kind.NOTE else "Пока пусто."
	else:
		_describe_item(list[0])


func _describe_item(id: StringName) -> void:
	if id == ItemCatalog.FLASK:
		_item_name.text = "Лечебное зелье"
		_item_text.text = "Глоток лечит часть здоровья. Пополняется при отдыхе у осколка. Ударили, пока пьёшь, — пролил.\n\nГлотков: %d" % _player.max_flasks()
		return
	_item_name.text = ItemCatalog.display_name(id)
	_item_text.text = ItemCatalog.description(id)


# ---------------------------------------------------------------- Открыть, закрыть, страницы

func open(player: Player, parent: Node3D) -> void:
	_player = player
	is_open = true
	visible = true
	player.frozen = true
	player.velocity = Vector3.ZERO
	player.hurtbox.invulnerable = true
	reflection = ShardReflection.spawn(parent, player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_page = Page.ROOT
	(get_parent() as Hud).prompt_label.visible = false
	(get_parent() as Hud).show_gameplay(false)
	_refresh()
	_focus_first()


func close() -> void:
	if not is_open or _animating:
		return
	# Неподтверждённые очки пропадают: ничего не потрачено.
	_pending.clear()
	_dialog.visible = false
	is_open = false
	visible = false
	if is_instance_valid(reflection):
		reflection.dismiss()
	reflection = null
	_player.frozen = false
	(get_parent() as Hud).prompt_label.visible = true
	(get_parent() as Hud).show_gameplay(true)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


## «Назад»: окно — закрыть, страница — к списку, список — отойти от осколка.
func back() -> void:
	if _dialog.visible:
		answer(false)
	elif _page != Page.ROOT:
		if _animating:
			return
		_pending.clear()
		show_page(Page.ROOT)
	else:
		close()


func show_page(page: Page) -> void:
	_page = page
	_refresh()
	_focus_first()


func _refresh() -> void:
	if _player == null:
		return
	for page: Page in _pages:
		(_pages[page] as Control).visible = page == _page
	# Корень — полупрозрачная полоса слева, чтобы видеть отражение; страницы — почти весь экран.
	_backdrop.anchor_right = 0.62
	_veil.visible = _page != Page.ROOT
	_confirm.visible = _page == Page.LEVEL
	var room := get_tree().get_first_node_in_group(&"room") as Room
	_caption.text = "Осколок Главного Зеркала" if _page == Page.ROOT else "Осколок · %s" % _place_name(room)
	_title.text = _place_name(room) if _page == Page.ROOT else PAGE_TITLES[_page]
	_hint.text = "[E] выбрать    [Esc] %s" % ("отойти" if _page == Page.ROOT else "назад")
	_hub.visible = hub_available
	_hub.disabled = _animating
	_leave.disabled = _animating
	for button in _root_buttons:
		button.disabled = _animating
	var stats := _player.stats
	_status.text = "Отзвуки %s    Уровень %d    Возраст %s" % [Hud._grouped(GameState.echoes), stats.level, _age_text(stats.current_age)]
	_refresh_level()
	match _page:
		Page.FACETS: _refresh_facets()
		Page.WEAPON: _refresh_weapon()
		Page.ITEMS: _refresh_items()


func _place_name(room: Room) -> String:
	if room == null:
		return "Осколок"
	return PLACE_NAMES.get(room.room_id, String(room.room_id).capitalize())


func _focus_first() -> void:
	match _page:
		Page.ROOT:
			_root_buttons[0].grab_focus()
		Page.LEVEL:
			if not _confirm.disabled:
				_confirm.grab_focus()
				return
			for param: PlayerStats.Param in PlayerStats.PARAM_ORDER:
				var button: Button = _buttons[param]
				if not button.disabled:
					button.grab_focus()
					return
		Page.FACETS:
			for child in _facet_grid.get_children():
				var button := child as Button
				if button and not button.disabled:
					button.grab_focus()
					return
		Page.WEAPON:
			if not _temper.disabled and _temper.visible:
				_temper.grab_focus()
			elif _weapon_switch.visible:
				_weapon_switch.grab_focus()
		Page.ITEMS:
			if _item_grid.get_child_count() > 0:
				(_item_grid.get_child(0) as Control).grab_focus()
			else:
				(_item_tabs.get_child(_item_kind) as Control).grab_focus()


# ---------------------------------------------------------------- Мелочи

func _arrow_int(a: int, b: int) -> String:
	return "%d → %d" % [a, b] if a != b else str(a)


func _arrow_text(a: String, b: String) -> String:
	return "%s → %s" % [a, b] if a != b else a


func _jump_height(stats: PlayerStats, at_age: float) -> float:
	var velocity := stats.jump_at(at_age)
	return velocity * velocity / (2.0 * stats.gravity)


func _age_text(age: float) -> String:
	return ("%.2f" % age).trim_suffix("0").trim_suffix(".0") if fmod(age, 1.0) != 0.0 else "%d" % int(age)


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Пункт меню: текст без рамки, выбранный — голубая полоса слева, как в месте благодати.
func _menu_button(parent: Control, text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = size + 18
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Color(0.79, 0.81, 0.84))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.5))
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 18
	plain.content_margin_right = 18
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0.72, 0.86, 1.0, 0.12)
	lit.border_color = ACCENT
	lit.border_width_left = 3
	lit.content_margin_left = 18
	lit.content_margin_right = 18
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, plain)
	for state in ["hover", "focus", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, lit)
	parent.add_child(button)
	return button


## Кнопка в рамке, как «Подтвердить» в макете: тёмная плашка с вертикальным градиентом в тонкой
## серой рамке, светлый текст с засечками по центру; выбранная — рамка светлее; недоступная — бледная.
func _frame_button(parent: Control, text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size.y = 60
	button.add_theme_font_override("font", _serif_font)
	button.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color(0.95, 0.95, 0.94))
	button.add_theme_color_override("font_disabled_color", Color(0.95, 0.95, 0.94, 0.35))
	button.add_theme_stylebox_override("normal", _plate(BUTTON))
	for state in ["hover", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, _plate(BUTTON_LIT))
	button.add_theme_stylebox_override("disabled", _plate(BUTTON_OFF))
	parent.add_child(button)
	return button


func _plate(texture: Texture2D) -> StyleBoxTexture:
	var plate := StyleBoxTexture.new()
	plate.texture = texture
	plate.set_texture_margin_all(3)
	plate.content_margin_left = 40
	plate.content_margin_right = 40
	plate.content_margin_top = 6
	plate.content_margin_bottom = 8
	return plate


## Заголовок раздела в рамке — как «Характеристики» и «Статус игрока» в Dark Souls: плашка
## тёмного металла с ромбом слева, текст с засечками.
func _section(parent: Control, text: String) -> PanelContainer:
	var plate := StyleBoxTexture.new()
	plate.texture = SECTION
	plate.texture_margin_left = 24
	plate.texture_margin_right = 4
	plate.texture_margin_top = 4
	plate.texture_margin_bottom = 4
	plate.content_margin_left = 28
	plate.content_margin_right = 12
	plate.content_margin_top = 3
	plate.content_margin_bottom = 4
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", plate)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var label := _label(panel, text, 21, Color(0.9, 0.88, 0.84))
	label.add_theme_font_override("font", _serif_font)
	return panel


func _small_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_font_size_override("font_size", 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.055, 0.07, 0.9)
	style.border_color = Color(0.66, 0.62, 0.55, 0.75)
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	var lit := style.duplicate() as StyleBoxFlat
	lit.border_color = Color(0.86, 0.93, 1.0)
	for state in ["hover", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, lit)
	var off := style.duplicate() as StyleBoxFlat
	off.border_color = Color(0.66, 0.62, 0.55, 0.25)
	button.add_theme_stylebox_override("disabled", off)
	parent.add_child(button)
	return button


func _icon_button(parent: Control, icon: Texture2D, size: int) -> Button:
	var button := Button.new()
	button.icon = icon
	button.expand_icon = true
	button.custom_minimum_size = Vector2(size, size)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0.05, 0.05, 0.06, 0.6)
	plain.border_color = Color(0.4, 0.39, 0.37, 0.6)
	plain.set_border_width_all(1)
	plain.set_content_margin_all(6)
	var lit := plain.duplicate() as StyleBoxFlat
	lit.border_color = Color.WHITE
	lit.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("disabled", plain)
	for state in ["hover", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, lit)
	parent.add_child(button)
	return button


static func _serif() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cormorant Garamond", "EB Garamond", "Georgia", "Times New Roman", "serif"])
	font.font_weight = 600
	return font


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
