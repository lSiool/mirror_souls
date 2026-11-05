class_name LevelMenu
extends Control
## Меню у осколка (§8.6): отзвуки превращаются в прожитые годы. Как в Dark Souls: сначала набрать
## очки по параметрам (один параметр — одно очко на уровень), потом «Подтвердить» и «Повысить
## уровень?». Рядом всегда видно, что возраст заберёт у тела: цена силы — лёгкость молодости.
## Чистое стекло освобождает очки: возраст при этом не меняется.
## Вторая страница — грани: надеть, снять, сколько слотов занято.
## Третья — оружие: закалка стеклом качает урон, мастерство типа растёт в бою и открывает приёмы.

signal closed
## Перенестись к главному осколку у часовни (хаб).
signal hub_requested

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
## Можно ли отсюда перенестись к главному осколку: выставляет RoomManager перед open().
var hub_available := false
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
var _hub: Button
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
var _bow_switch: Button
var _weapon_switch: Button
## Набранные, но ещё не подтверждённые очки: параметр → сколько.
var _pending := {}
var _minus := {}
var _confirm: Button
var _dialog: PanelContainer
var _dialog_label: Label
var _yes: Button


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
		var row := HBoxContainer.new()
		_level_page.add_child(row)
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 40
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: choose(param))
		row.add_child(button)
		_buttons[param] = button
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(40, 40)
		minus.pressed.connect(func() -> void: unchoose(param))
		row.add_child(minus)
		_minus[param] = minus
	_confirm = Button.new()
	_confirm.custom_minimum_size.y = 40
	_confirm.pressed.connect(confirm)
	_level_page.add_child(_confirm)
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
	_bow_switch = Button.new()
	_bow_switch.custom_minimum_size.y = 36
	_bow_switch.pressed.connect(switch_bow)
	_weapon_page.add_child(_bow_switch)
	_weapon_switch = Button.new()
	_weapon_switch.custom_minimum_size.y = 36
	_weapon_switch.pressed.connect(switch_weapon)
	_weapon_page.add_child(_weapon_switch)
	_weapon_page.add_child(HSeparator.new())
	_mastery_label = _line(_weapon_page)
	_hub = Button.new()
	_hub.text = "Перенестись к главному осколку — у часовни"
	_hub.custom_minimum_size.y = 36
	_hub.pressed.connect(go_to_hub)
	column.add_child(_hub)
	_leave = Button.new()
	_leave.text = "Отойти"
	_leave.custom_minimum_size.y = 36
	_leave.pressed.connect(close)
	column.add_child(_leave)
	_build_dialog()


## Закрыть меню и перенестись к главному осколку.
func go_to_hub() -> void:
	if not hub_available or _animating:
		return
	close()
	hub_requested.emit()


## Окно «Повысить уровень?» поверх меню.
func _build_dialog() -> void:
	_dialog = PanelContainer.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.97)
	style.border_color = Color(0.72, 0.86, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_content_margin_all(26)
	_dialog.add_theme_stylebox_override("panel", style)
	_dialog.visible = false
	add_child(_dialog)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(380, 0)
	column.add_theme_constant_override("separation", 14)
	_dialog.add_child(column)
	_dialog_label = Label.new()
	_dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_dialog_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_yes = Button.new()
	_yes.text = "Да"
	_yes.custom_minimum_size = Vector2(120, 40)
	_yes.pressed.connect(func() -> void: answer(true))
	buttons.add_child(_yes)
	var no := Button.new()
	no.text = "Нет"
	no.custom_minimum_size = Vector2(120, 40)
	no.pressed.connect(func() -> void: answer(false))
	buttons.add_child(no)


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
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _dialog.visible:
			answer(false)
		else:
			close()


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


## Набрать очко в параметр — пока без траты: применится после подтверждения.
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
	for param: PlayerStats.Param in PARAMS:
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


## Взять в руку другой лук, если их два.
func switch_bow() -> void:
	var bows := GameState.owned_bows()
	if bows.size() < 2:
		return
	GameState.bow_id = bows[(bows.find(GameState.bow_id) + 1) % bows.size()]
	Sfx.play(&"glass_glint", _player.global_position, -12.0)
	_refresh()


## Взять в руку следующее оружие из того, что герой носит с собой.
func switch_weapon() -> void:
	var owned := GameState.owned_weapons()
	if owned.size() < 2:
		return
	_player.equip(owned[(owned.find(GameState.weapon_id) + 1) % owned.size()])
	Sfx.play(&"glass_glint", _player.global_position, -12.0)
	_refresh()


func _refresh_weapon() -> void:
	var owned := GameState.owned_weapons()
	_weapon_switch.visible = owned.size() >= 2
	if owned.size() >= 2:
		var next: StringName = owned[(owned.find(GameState.weapon_id) + 1) % owned.size()]
		var held := _player.weapon.display_name if _player.weapon else "—"
		_weapon_switch.text = "Оружие: %s → взять %s" % [held, WeaponData.by_id(next).display_name.to_lower()]
	var bows := GameState.owned_bows()
	_bow_switch.visible = bows.size() >= 2
	if bows.size() >= 2:
		var other: StringName = bows[(bows.find(GameState.bow_id) + 1) % bows.size()]
		_bow_switch.text = "Лук: %s → взять %s" % [GameState.BOWS.get(GameState.bow_id, ["—"])[0], GameState.BOWS[other][0]]
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
	_hub.visible = hub_available
	_hub.disabled = _animating
	if _page == Page.FACETS:
		_refresh_facets()
		return
	if _page == Page.WEAPON:
		_refresh_weapon()
		return
	var stats := _player.stats
	var free := stats.unspent > pending_total()
	var levels := pending_levels()
	var shown := maxi(levels, 0 if free else 1)
	_echoes_label.text = "Отзвуки: %d" % GameState.echoes
	if stats.unspent > 0:
		_level_label.text = "Свободных очков: %d — без отзвуков и без новых лет" % (stats.unspent - mini(pending_total(), stats.unspent))
	else:
		_level_label.text = "Уровень %d → %d · цена %d" % [stats.level, stats.level + shown, stats.cost_of_levels(shown)]
	var next_age := stats.age_at(stats.level + shown)
	if next_age > stats.current_age:
		_age_label.text = "Возраст: %s → %s" % [_age_text(stats.current_age), _age_text(next_age)]
	elif shown > 0:
		_age_label.text = "Возраст: %s — годы больше не прибавляются" % _age_text(stats.current_age)
	else:
		_age_label.text = "Возраст: %s" % _age_text(stats.current_age)
	var can_add := _can_add()
	for param: PlayerStats.Param in PARAMS:
		var button: Button = _buttons[param]
		var picked: int = _pending.get(param, 0)
		button.text = "%s:  %s%s" % [PARAMS[param], _param_change(param), "   +%d" % picked if picked > 0 else ""]
		button.disabled = _animating or not can_add
		var minus: Button = _minus[param]
		minus.disabled = _animating or picked == 0
	var total := pending_total()
	_confirm.disabled = _animating or total == 0 or GameState.echoes < pending_cost()
	if total == 0:
		_confirm.text = "Подтвердить — сначала выберите, что улучшить"
	elif levels > 0:
		_confirm.text = "Подтвердить: уровней %d, отзвуков %d" % [levels, pending_cost()]
	else:
		_confirm.text = "Подтвердить: очков %d" % total
	_body_label.text = _body_change(shown) if shown > 0 else ""
	_body_label.visible = shown > 0
	_respec.visible = GameState.item_count(CLEAR_GLASS) > 0
	_respec.text = "Чистое стекло (%d): перераспределить очки" % GameState.item_count(CLEAR_GLASS)
	_respec.disabled = _animating
	_leave.disabled = _animating


## Сейчас → с набранными очками (ничего не набрано — с одним очком).
func _param_change(param: PlayerStats.Param) -> String:
	var stats := _player.stats
	var extra: int = maxi(_pending.get(param, 0), 1)
	var next_age := stats.age_at(stats.level + maxi(pending_levels(), 0 if stats.unspent > pending_total() else 1))
	match param:
		PlayerStats.Param.HEALTH:
			return "%.0f → %.0f" % [stats.max_health, stats.base_health + stats.bonus_with(param, extra)]
		PlayerStats.Param.STAMINA:
			return "%.0f → %.0f" % [stats.max_stamina, stats.base_stamina + stats.bonus_with(param, extra)]
		PlayerStats.Param.STRENGTH:
			return "урон %.1f → %.1f" % [stats.sword_damage, stats.damage_at(next_age) * (1.0 + stats.bonus_with(param, extra))]
		_:
			return "урон %.1f → %.1f" % [stats.bow_damage_max * stats.bow_damage_mult,
				stats.bow_damage_max * (1.0 + stats.bonus_with(param, extra))]


## Что годы заберут за столько уровней.
func _body_change(levels: int) -> String:
	var stats := _player.stats
	var now := stats.current_age
	var next := stats.age_at(stats.level + levels)
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
	if not _confirm.disabled:
		_confirm.grab_focus()
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
