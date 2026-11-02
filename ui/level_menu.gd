class_name LevelMenu
extends Control
## Меню у осколка (§8.6): отзвуки превращаются в прожитые годы. Выбор — один параметр на уровень;
## рядом всегда видно, что возраст заберёт у тела: цена силы — лёгкость молодости.
## Чистое стекло освобождает очки: возраст при этом не меняется.
## Вторая страница — грани: надеть, снять, сколько слотов занято.
## Третья — оружие: закалка стеклом качает урон, мастерство типа растёт в бою и открывает приёмы.

signal closed

const CLEAR_GLASS: StringName = &"clear_glass"
const FACET_SLOT: StringName = &"facet_slot"
const TYPE_NAMES := {&"sword": "Меч", &"bow": "Лук", &"spear": "Копьё", &"axe": "Топор", &"hammer": "Молот"}

enum Page { LEVEL, FACETS, WEAPON }
const PARAMS := {
	PlayerStats.Param.HEALTH: "Здоровье",
	PlayerStats.Param.STAMINA: "Выносливость",
	PlayerStats.Param.STRENGTH: "Сила — меч",
	PlayerStats.Param.DEXTERITY: "Меткость — лук",
}

var is_open := false
var reflection: ShardReflection
var _player: Player
var _animating := false
var _echoes_label: Label
var _level_label: Label
var _age_label: Label
var _body_label: Label
var _buttons := {}
var _respec: Button
var _leave: Button
var _level_tab: Button
var _facet_tab: Button
var _level_page: VBoxContainer
var _facet_page: VBoxContainer
var _slots_label: Label
var _facet_list: VBoxContainer
var _facet_text: Label
var _page := Page.LEVEL
var _weapon_tab: Button
var _weapon_page: VBoxContainer
var _temper: Button
var _glass_label: Label
var _mastery_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	style.border_color = Color(0.45, 0.72, 1.0, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(470, 0)
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Отражение в осколке"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	column.add_child(title)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	_level_tab = _tab(tabs, "Уровень", Page.LEVEL)
	_facet_tab = _tab(tabs, "Грани", Page.FACETS)
	_weapon_tab = _tab(tabs, "Оружие", Page.WEAPON)
	_level_page = VBoxContainer.new()
	_level_page.add_theme_constant_override("separation", 10)
	column.add_child(_level_page)
	_echoes_label = _line(_level_page)
	_level_label = _line(_level_page)
	_age_label = _line(_level_page)
	_level_page.add_child(HSeparator.new())
	for param: PlayerStats.Param in PARAMS:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 40
		button.pressed.connect(func() -> void: choose(param))
		_level_page.add_child(button)
		_buttons[param] = button
	_level_page.add_child(HSeparator.new())
	_body_label = _line(_level_page)
	_body_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_respec = Button.new()
	_respec.custom_minimum_size.y = 36
	_respec.pressed.connect(use_clear_glass)
	_level_page.add_child(_respec)
	_facet_page = VBoxContainer.new()
	_facet_page.add_theme_constant_override("separation", 8)
	column.add_child(_facet_page)
	_slots_label = _line(_facet_page)
	_facet_list = VBoxContainer.new()
	_facet_page.add_child(_facet_list)
	_facet_page.add_child(HSeparator.new())
	_facet_text = _line(_facet_page)
	_facet_text.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_facet_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facet_text.custom_minimum_size.y = 48
	_weapon_page = VBoxContainer.new()
	_weapon_page.add_theme_constant_override("separation", 10)
	column.add_child(_weapon_page)
	_glass_label = _line(_weapon_page)
	_temper = Button.new()
	_temper.custom_minimum_size.y = 40
	_temper.pressed.connect(temper)
	_weapon_page.add_child(_temper)
	_weapon_page.add_child(HSeparator.new())
	_mastery_label = _line(_weapon_page)
	_leave = Button.new()
	_leave.text = "Отойти"
	_leave.custom_minimum_size.y = 36
	_leave.pressed.connect(close)
	column.add_child(_leave)


func open(player: Player, parent: Node3D) -> void:
	_player = player
	is_open = true
	visible = true
	player.frozen = true
	player.velocity = Vector3.ZERO
	player.hurtbox.invulnerable = true
	reflection = ShardReflection.spawn(parent, player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_page = Page.LEVEL
	(get_parent() as Hud).prompt_label.visible = false
	_refresh()
	_focus_first()


func close() -> void:
	if not is_open or _animating:
		return
	is_open = false
	visible = false
	if is_instance_valid(reflection):
		reflection.dismiss()
	reflection = null
	_player.frozen = false
	(get_parent() as Hud).prompt_label.visible = true
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Вложить очко. Свободное (после чистого стекла) — сразу; иначе новый уровень: отзвуки текут
## в отражение, оно на миг взрослеет, потом прожитое переходит на героя.
func choose(param: PlayerStats.Param) -> void:
	var stats := _player.stats
	if _animating:
		return
	if stats.unspent > 0:
		stats.spend_unspent(param)
		_refresh()
		return
	var cost := stats.level_cost()
	if GameState.echoes < cost:
		return
	_animating = true
	GameState.add_echoes(-cost)
	_refresh()
	var from := _player.global_position + Vector3(0.0, 1.1, 0.0)
	var to := reflection.global_position + Vector3(0.0, 1.1, 0.0)
	for i in 5:
		EchoDrop.stream(reflection.get_parent(), from + Vector3(0.0, randf_range(-0.3, 0.3), 0.0), to, 0.4 + i * 0.05)
	await get_tree().create_timer(0.3).timeout
	Sfx.play(&"glass_glint", to, -6.0)
	await reflection.play_level_up(stats.age_at(stats.level + 1))
	stats.level_up(param)
	Sfx.play(&"glass_glint", from, -6.0)
	HitSpark.spawn(reflection.get_parent(), from, EchoDrop.COLOR, 16)
	_player.body.flash(EchoDrop.COLOR)
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


func show_page(page: Page) -> void:
	_page = page
	_refresh()
	_focus_first()


## Закалить оружие в руке.
func temper() -> void:
	if _player.weapon and GameState.temper(_player.weapon.id):
		Sfx.play(&"glass_glint", _player.global_position, -6.0)
	_refresh()
	_focus_first()


func _refresh_weapon() -> void:
	var weapon := _player.weapon
	_temper.visible = weapon != null
	if weapon == null:
		_glass_label.text = "В руках ничего нет."
		_mastery_label.text = ""
		return
	var level := GameState.glass_level(weapon.id)
	var damage := _player._blade_damage()
	_glass_label.text = "%s · закалка +%d · урон %.1f\nЗакалённое стекло: %d · отзвуки: %d" % [weapon.display_name, level, damage, GameState.item_count(GameState.GLASS_ITEM), GameState.echoes]
	if level >= GameState.GLASS_MATERIAL.size():
		_temper.text = "Закалка завершена"
		_temper.disabled = true
	else:
		_temper.text = "Закалить: +%d, стекла %d, отзвуков %d" % [level + 1, GameState.GLASS_MATERIAL[level], GameState.GLASS_ECHOES[level]]
		_temper.disabled = GameState.item_count(GameState.GLASS_ITEM) < GameState.GLASS_MATERIAL[level] or GameState.echoes < GameState.GLASS_ECHOES[level]
	var step := GameState.mastery_step(weapon.type)
	var lines: Array[String] = ["Заряженный удар и блок — сразу. Мастерство растёт в бою:"]
	for i in weapon.step_names.size():
		lines.append("%s %d. %s" % ["◆" if i < step else "◇", i + 1, weapon.step_names[i]])
	lines.append("")
	for type: StringName in TYPE_NAMES:
		if GameState.mastery_xp(type) > 0.0 or type == weapon.type:
			lines.append(_mastery_line(type))
	_mastery_label.text = "\n".join(lines)


func _mastery_line(type: StringName) -> String:
	var progress := GameState.mastery_progress(type)
	var step := GameState.mastery_step(type)
	if progress == Vector2.ZERO:
		return "%s: ступень %d — мастер" % [TYPE_NAMES[type], step]
	return "%s: ступень %d, до следующей %.0f из %.0f" % [TYPE_NAMES[type], step, progress.x, progress.y]


## Слотов всего: стартовые и найденные.
func facet_slots() -> int:
	return PlayerStats.BASE_FACET_SLOTS + GameState.item_count(FACET_SLOT)


## Надеть или снять грань.
func toggle_facet(facet: Facet) -> void:
	if _player.stats.toggle_facet(facet, facet_slots()):
		Sfx.play(&"glass_glint", _player.global_position, -12.0)
	_refresh()
	_focus_facet(facet)


func _refresh_facets() -> void:
	var stats := _player.stats
	_slots_label.text = "Слоты: занято %d из %d" % [stats.facet_slots_used(), facet_slots()]
	for child in _facet_list.get_children():
		_facet_list.remove_child(child)
		child.queue_free()
	for facet in Facet.catalog():
		if GameState.item_count(facet.id) <= 0:
			continue
		var worn := facet in stats.facets
		var button := Button.new()
		button.name = String(facet.id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 34
		button.icon = facet.icon
		button.text = "%s  %s  · слотов %d" % ["◆" if worn else "◇", facet.display_name, facet.cost]
		button.disabled = not worn and stats.facet_slots_used() + facet.cost > facet_slots()
		button.pressed.connect(toggle_facet.bind(facet))
		button.focus_entered.connect(_describe.bind(facet))
		button.mouse_entered.connect(_describe.bind(facet))
		_facet_list.add_child(button)


## Описание грани; у возрастной — её сила сейчас.
func _describe(facet: Facet) -> void:
	var text := facet.description
	if facet.age_curve != Facet.AgeCurve.NONE:
		text += "\nСила в %s лет: %d %%" % [_age_text(_player.stats.current_age), roundi(facet.strength(_player.stats.current_age) * 100.0)]
	_facet_text.text = text


func _focus_facet(facet: Facet) -> void:
	var button := _facet_list.get_node_or_null(String(facet.id)) as Button
	if button and not button.disabled:
		button.grab_focus()
		_describe(facet)
	else:
		_facet_tab.grab_focus()


func _refresh() -> void:
	_level_page.visible = _page == Page.LEVEL
	_facet_page.visible = _page == Page.FACETS
	_weapon_page.visible = _page == Page.WEAPON
	_level_tab.disabled = _page == Page.LEVEL or _animating
	_facet_tab.disabled = _page == Page.FACETS or _animating
	_weapon_tab.disabled = _page == Page.WEAPON or _animating
	_leave.disabled = _animating
	if _page == Page.FACETS:
		_refresh_facets()
		return
	if _page == Page.WEAPON:
		_refresh_weapon()
		return
	var stats := _player.stats
	var free := stats.unspent > 0
	var cost := stats.level_cost()
	_echoes_label.text = "Отзвуки: %d" % GameState.echoes
	if free:
		_level_label.text = "Свободных очков: %d — без отзвуков и без новых лет" % stats.unspent
		_age_label.text = "Возраст: %s" % _age_text(stats.current_age)
	else:
		_level_label.text = "Уровень %d → %d · цена %d" % [stats.level, stats.level + 1, cost]
		var next_age := stats.age_at(stats.level + 1)
		if next_age > stats.current_age:
			_age_label.text = "Возраст: %s → %s" % [_age_text(stats.current_age), _age_text(next_age)]
		else:
			_age_label.text = "Возраст: %s — годы больше не прибавляются" % _age_text(stats.current_age)
	var can_pay := free or GameState.echoes >= cost
	for param: PlayerStats.Param in PARAMS:
		var button: Button = _buttons[param]
		button.text = "%s:  %s" % [PARAMS[param], _param_change(param)]
		button.disabled = _animating or not can_pay
	_body_label.text = "" if free else _body_change()
	_body_label.visible = not free
	_respec.visible = GameState.item_count(CLEAR_GLASS) > 0
	_respec.text = "Чистое стекло (%d): перераспределить очки" % GameState.item_count(CLEAR_GLASS)
	_respec.disabled = _animating
	_leave.disabled = _animating


func _param_change(param: PlayerStats.Param) -> String:
	var stats := _player.stats
	var next_age := stats.current_age if stats.unspent > 0 else stats.age_at(stats.level + 1)
	match param:
		PlayerStats.Param.HEALTH:
			return "%.0f → %.0f" % [stats.max_health, stats.base_health + stats.bonus_with(param, 1)]
		PlayerStats.Param.STAMINA:
			return "%.0f → %.0f" % [stats.max_stamina, stats.base_stamina + stats.bonus_with(param, 1)]
		PlayerStats.Param.STRENGTH:
			return "урон %.1f → %.1f" % [stats.sword_damage, stats.damage_at(next_age) * (1.0 + stats.bonus_with(param, 1))]
		_:
			return "урон %.1f → %.1f" % [stats.bow_damage_max * stats.bow_damage_mult,
				stats.bow_damage_max * (1.0 + stats.bonus_with(param, 1))]


## Что годы заберут при любом выборе.
func _body_change() -> String:
	var stats := _player.stats
	var now := stats.current_age
	var next := stats.age_at(stats.level + 1)
	if next <= now:
		return "Тело больше не меняется."
	return "Годы заберут: скорость %.2f → %.2f · прыжок %.2f → %.2f м · неуязвимость переката %.3f → %.3f с" % [
		stats.speed_at(now), stats.speed_at(next),
		_jump_height(stats, now), _jump_height(stats, next),
		stats.iframes_at(now), stats.iframes_at(next)]


func _jump_height(stats: PlayerStats, at_age: float) -> float:
	var velocity := stats.jump_at(at_age)
	return velocity * velocity / (2.0 * stats.gravity)


func _age_text(age: float) -> String:
	return ("%.2f" % age).trim_suffix("0").trim_suffix(".0") if fmod(age, 1.0) != 0.0 else "%d" % int(age)


func _focus_first() -> void:
	if _page == Page.WEAPON:
		if _temper.disabled:
			_leave.grab_focus()
		else:
			_temper.grab_focus()
		return
	if _page == Page.FACETS:
		var first := _facet_list.get_child(0) as Button if _facet_list.get_child_count() > 0 else null
		if first and not first.disabled:
			first.grab_focus()
			first.focus_entered.emit()
		else:
			_leave.grab_focus()
		return
	for param: PlayerStats.Param in PARAMS:
		var button: Button = _buttons[param]
		if not button.disabled:
			button.grab_focus()
			return
	_leave.grab_focus()


func _tab(parent: Control, text: String, page: Page) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 34
	button.pressed.connect(show_page.bind(page))
	parent.add_child(button)
	return button


func _line(parent: Control) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label
