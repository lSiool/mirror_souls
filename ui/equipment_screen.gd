class_name EquipmentScreen
extends HBoxContainer
## Экран «Снаряжение» (§8.12, 2026-11-09) — в духе Dark Souls 3: слева ряды ячеек (правая рука —
## оружие I и II, левая — щиты I и II, отдельно лук и стрелы), справа герой
## в том, что надето. Ячейка выбрана — внизу имя и описание; нажата — рядом список того, что можно
## надеть. Меняется где угодно, кроме стрел: их гнёзда выбираются только у осколка (§6.2).
## Броня — пустые ячейки на будущее.

enum Slot { WEAPON_1, WEAPON_2, SHIELD, BOW, ARROW_1, ARROW_2, ITEM_1, ITEM_2, ITEM_3, ITEM_4, HEAD, BODY, HANDS, LEGS, SHIELD_2 }

## Ряды: подпись и ячейки.
const ROWS := [
	["Правая рука", [Slot.WEAPON_1, Slot.WEAPON_2]],
	["Левая рука", [Slot.SHIELD, Slot.SHIELD_2]],
	["Лук · Стрелы", [Slot.BOW, Slot.ARROW_1, Slot.ARROW_2]],
	["Расходники", [Slot.ITEM_1, Slot.ITEM_2, Slot.ITEM_3, Slot.ITEM_4]],
	["Броня", [Slot.HEAD, Slot.BODY, Slot.HANDS, Slot.LEGS]],
]
const SLOT_NAMES := {
	Slot.WEAPON_1: "Оружие I", Slot.WEAPON_2: "Оружие II", Slot.SHIELD: "Щит I", Slot.SHIELD_2: "Щит II", Slot.BOW: "Лук",
	Slot.ARROW_1: "Стрелы I", Slot.ARROW_2: "Стрелы II", Slot.ITEM_1: "Расходник · верх",
	Slot.ITEM_2: "Расходник · лево", Slot.ITEM_3: "Расходник · право", Slot.ITEM_4: "Расходник · низ",
	Slot.HEAD: "Голова", Slot.BODY: "Тело", Slot.HANDS: "Руки", Slot.LEGS: "Ноги",
}
## Подпись в углу ячейки.
const SLOT_TAGS := {
	Slot.WEAPON_1: "I", Slot.WEAPON_2: "II", Slot.SHIELD: "I", Slot.SHIELD_2: "II", Slot.ARROW_1: "I", Slot.ARROW_2: "II",
	Slot.ITEM_1: "1", Slot.ITEM_2: "2", Slot.ITEM_3: "3", Slot.ITEM_4: "4",
}
## Значок пустой ячейки.
const EMPTY_ICONS := {
	Slot.WEAPON_1: &"slot_weapon", Slot.WEAPON_2: &"slot_weapon", Slot.SHIELD: &"slot_shield",
	Slot.SHIELD_2: &"slot_shield", Slot.BOW: &"slot_bow",
	Slot.ARROW_1: &"slot_arrow", Slot.ARROW_2: &"slot_arrow", Slot.ITEM_1: &"slot_item", Slot.ITEM_2: &"slot_item",
	Slot.ITEM_3: &"slot_item", Slot.ITEM_4: &"slot_item", Slot.HEAD: &"slot_head", Slot.BODY: &"slot_body",
	Slot.HANDS: &"slot_hands", Slot.LEGS: &"slot_legs",
}
const ARMOR: Array[Slot] = [Slot.HEAD, Slot.BODY, Slot.HANDS, Slot.LEGS]
const CELL := 84
## Пусто в списке выбора.
const NONE := &"-"

var menu: LevelMenu
var _player: Player
var _cells := {}
var _name: Label
var _text: Label
var _list_box: VBoxContainer
var _list_title: Label
var _list: VBoxContainer
var _choosing := -1
var _figure: HeroModel
var _viewport: SubViewport


func setup(owner_menu: LevelMenu) -> void:
	menu = owner_menu
	add_theme_constant_override("separation", 40)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size.x = 560
	add_child(left)
	for row: Array in ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		left.add_child(line)
		var tag := menu._label(line, row[0], 20, LevelMenu.MUTED)
		tag.custom_minimum_size.x = 150
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for slot: Slot in row[1]:
			_cells[slot] = _cell(line, slot)
	left.add_child(menu._spacer(8))
	_name = menu._label(left, "", 32, LevelMenu.TEXT)
	_name.add_theme_font_override("font", menu._serif_font)
	_text = menu._label(left, "", 19, Color(0.83, 0.85, 0.87))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 540
	# Список выбора — между ячейками и героем, виден, пока выбирают.
	_list_box = VBoxContainer.new()
	_list_box.custom_minimum_size.x = 340
	_list_box.add_theme_constant_override("separation", 6)
	_list_box.visible = false
	add_child(_list_box)
	_list_title = menu._label(_list_box, "", 22, LevelMenu.BRONZE)
	_list_title.add_theme_font_override("font", menu._serif_font)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list_box.add_child(_list)
	_build_figure()


func _cell(parent: Control, slot: Slot) -> Button:
	var button := menu._icon_button(parent, null, CELL)
	button.focus_entered.connect(_describe.bind(slot))
	button.mouse_entered.connect(_describe.bind(slot))
	button.pressed.connect(_choose.bind(slot))
	if SLOT_TAGS.has(slot):
		var tag := menu._label(button, SLOT_TAGS[slot], 17, LevelMenu.BRONZE)
		tag.position = Vector2(8, 4)
		_outline(tag)
	var count := menu._label(button, "", 17, LevelMenu.TEXT)
	_outline(count)
	count.name = &"Count"
	count.position = Vector2(CELL - 30, CELL - 26)
	return button


## Подпись поверх значка: тёмная обводка, чтобы читалась на любом рисунке.
static func _outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))


## Герой в том, что надето: своя маленькая сцена с манекеном, светом и камерой.
func _build_figure() -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(380, 560)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL | Control.SIZE_SHRINK_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.environment.ambient_light_energy = 0.6
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.7, 0.0)
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.92, 0.82)
	_viewport.add_child(key)
	# Холодный контровой свет сзади — силуэт читается на тёмном фоне.
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.6, 0.0)
	rim.light_energy = 1.6
	rim.light_color = Color(0.6, 0.75, 1.0)
	_viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0.0, 1.0, 4.2)
	camera.rotation.x = -0.04
	_viewport.add_child(camera)
	# Манекен смотрит вправо (+X); разворачиваем его к камере в три четверти.
	var turn := Node3D.new()
	turn.rotation.y = -PI * 0.5 + 0.55
	_viewport.add_child(turn)
	_figure = HeroModel.new()
	turn.add_child(_figure)


func refresh(player: Player) -> void:
	_player = player
	for slot: Slot in _cells:
		var button: Button = _cells[slot]
		var id := _item_in(slot)
		var empty := id == &"" or id == NONE
		var locked := _locked(slot)
		button.icon = ItemCatalog.icon(EMPTY_ICONS[slot] if empty else id)
		button.modulate = Color(1, 1, 1, 0.55) if slot in ARMOR or locked else Color.WHITE
		var count := button.get_node("Count") as Label
		count.text = str(GameState.item_count(id)) if not empty and _counts(slot) else ""
	_dress_figure()
	if _choosing >= 0:
		_fill_list(_choosing)


func focus_first() -> void:
	(_cells[Slot.WEAPON_1] as Button).grab_focus()


## Открыт ли список выбора — «Назад» сперва закрывает его.
func list_open() -> bool:
	return _list_box.visible


func close_list() -> void:
	var slot := _choosing
	_choosing = -1
	_list_box.visible = false
	if slot >= 0:
		(_cells[slot] as Button).grab_focus()


# ---------------------------------------------------------------- Что где лежит

func _item_in(slot: Slot) -> StringName:
	match slot:
		Slot.WEAPON_1: return GameState.weapon_id
		Slot.WEAPON_2: return GameState.second_weapon_id
		Slot.SHIELD, Slot.SHIELD_2:
			var id: StringName = GameState.shield_slots[0 if slot == Slot.SHIELD else 1]
			return id if id != &"" and GameState.item_count(id) > 0 else &""
		Slot.BOW: return GameState.bow_id if GameState.has_flag(&"has_bow") else &""
		Slot.ARROW_1, Slot.ARROW_2:
			if not GameState.has_flag(&"has_bow"):
				return &""
			var id: StringName = GameState.arrow_slots[slot - Slot.ARROW_1]
			return id if id != &"" else ItemCatalog.ARROW
		Slot.ITEM_1, Slot.ITEM_2, Slot.ITEM_3, Slot.ITEM_4:
			return GameState.quick_item(slot - Slot.ITEM_1)
	return &""


func _counts(slot: Slot) -> bool:
	if slot in [Slot.ARROW_1, Slot.ARROW_2]:
		return _item_in(slot) != ItemCatalog.ARROW
	return slot >= Slot.ITEM_1 and slot <= Slot.ITEM_4


## Стрелы меняются только у осколка; броня — пока пустые ячейки.
func _locked(slot: Slot) -> bool:
	return slot in [Slot.ARROW_1, Slot.ARROW_2] and not menu.at_shard


## Что можно положить в ячейку; NONE — снять.
func _choices(slot: Slot) -> Array[StringName]:
	var result: Array[StringName] = []
	match slot:
		Slot.WEAPON_1:
			result.append_array(GameState.owned_weapons())
		Slot.WEAPON_2:
			result.append(NONE)
			for id in GameState.owned_weapons():
				if id != GameState.weapon_id:
					result.append(id)
		Slot.SHIELD, Slot.SHIELD_2:
			result.append(NONE)
			if GameState.item_count(GameState.SHIELD_ITEM) > 0:
				result.append(GameState.SHIELD_ITEM)
		Slot.BOW:
			if GameState.has_flag(&"has_bow"):
				result.append_array(GameState.owned_bows())
		Slot.ARROW_1, Slot.ARROW_2:
			if GameState.has_flag(&"has_bow"):
				result.append(ItemCatalog.ARROW)
				result.append_array(GameState.owned_arrows())
		Slot.ITEM_1, Slot.ITEM_2, Slot.ITEM_3, Slot.ITEM_4:
			result.append(NONE)
			for id: StringName in ItemCatalog.ITEMS:
				if GameState.is_consumable(id) and GameState.item_count(id) > 0:
					result.append(id)
	return result


# ---------------------------------------------------------------- Описание и выбор

func _describe(slot: Slot) -> void:
	var id := _item_in(slot)
	if slot in ARMOR:
		_name.text = SLOT_NAMES[slot]
		_text.text = "Брони пока нет. Найденные доспехи будут надеваться здесь."
		return
	if id == &"":
		_name.text = SLOT_NAMES[slot]
		_text.text = "Пусто."
		return
	_name.text = "%s — %s" % [SLOT_NAMES[slot], ItemCatalog.display_name(id) if id != ItemCatalog.ARROW else "Обычные стрелы"]
	var text := ItemCatalog.description(id) if id != ItemCatalog.ARROW else "Бесконечные. Лежат в гнезде, когда в нём нет особых."
	if _counts(slot):
		text += "\n\nОсталось: %d" % GameState.item_count(id)
	if _locked(slot):
		text += "\n\nГнёзда стрел выбираются у осколка; в бою — смена I / II (T, крестовина вправо)."
	_text.text = text


func _choose(slot: Slot) -> void:
	if slot in ARMOR or _locked(slot):
		return
	var choices := _choices(slot)
	if choices.size() < 2 and not (choices.size() == 1 and choices[0] != _item_in(slot)):
		return
	_choosing = slot
	_list_box.visible = true
	_fill_list(slot)


func _fill_list(slot: Slot) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_list_title.text = SLOT_NAMES[slot]
	var now := _item_in(slot)
	var first: Button
	for id in _choices(slot):
		var title := "Снять" if id == NONE else ("Обычные стрелы" if id == ItemCatalog.ARROW else ItemCatalog.display_name(id))
		if id != NONE and (GameState.is_consumable(id) or GameState.is_arrow(id)):
			title += "  ×%d" % GameState.item_count(id)
		var button := menu._menu_button(_list, title, 22)
		if id != NONE:
			button.icon = ItemCatalog.icon(id)
			button.expand_icon = false
			button.add_theme_constant_override("icon_max_width", 36)
		if id == now or (id == NONE and now == &""):
			button.add_theme_color_override("font_color", LevelMenu.ACCENT)
		button.pressed.connect(_put.bind(slot, id))
		if first == null:
			first = button
	if first:
		first.grab_focus()


func _put(slot: Slot, id: StringName) -> void:
	var item := &"" if id == NONE else id
	match slot:
		Slot.WEAPON_1:
			if item != GameState.weapon_id:
				if item == GameState.second_weapon_id:
					GameState.second_weapon_id = GameState.weapon_id
				_player.equip(item)
		Slot.WEAPON_2:
			GameState.second_weapon_id = item
		Slot.SHIELD, Slot.SHIELD_2:
			GameState.set_shield_slot(0 if slot == Slot.SHIELD else 1, item)
			_player.refresh_shield()
		Slot.BOW:
			GameState.bow_id = item
		Slot.ARROW_1, Slot.ARROW_2:
			GameState.set_arrow_slot(slot - Slot.ARROW_1, &"" if item == ItemCatalog.ARROW else item)
		Slot.ITEM_1, Slot.ITEM_2, Slot.ITEM_3, Slot.ITEM_4:
			GameState.set_quick_slot(slot - Slot.ITEM_1, item)
	Sfx.play(&"glass_glint", _player.global_position, -12.0)
	close_list()
	refresh(_player)
	_describe(slot)


## Манекен на экране держит то же оружие, что герой.
func _dress_figure() -> void:
	if _figure == null or _figure.hand == null or _player == null or _player.model == null:
		return
	for old in _figure.hand.get_children():
		old.free()
	for part in _player.model.hand.get_children():
		_figure.hand.add_child(part.duplicate())
	_figure.hand.visible = _player.weapon != null
	# Щит — на предплечье, с двуручным — за спиной.
	for mount in [_figure.shield_mount, _figure.back_mount]:
		for old in mount.get_children():
			old.free()
	var on_arm := _player.shield_in_hand()
	if _player.has_shield():
		var shield := _player.arms.shield_node().duplicate() as Node3D
		(_figure.shield_mount if on_arm else _figure.back_mount).add_child(shield)
		shield.transform = Transform3D.IDENTITY
		shield.visible = true
	if on_arm:
		_figure.play(&"Idle_Shield")
	else:
		_figure.play(&"Sword_Idle" if _player.weapon else &"Idle")
