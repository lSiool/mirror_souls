class_name PausePanel
extends PanelContainer
## Меню паузы (§8.12, 2026-11-09) — компактная панель слева вверху, как в Dark Souls 3:
## мир за ней виден и не останавливается. Ряд вкладок-значков, под ним — имя выбранной.
## «Выход» раскрывает два пункта: в главное меню или вернуться.

signal page_chosen(page: LevelMenu.Page)
signal exit_to_title
signal resume

const TABS := [
	[&"menu_equipment", "Снаряжение", LevelMenu.Page.EQUIP],
	[&"menu_items", "Предметы", LevelMenu.Page.ITEMS],
	[&"menu_status", "Статус", LevelMenu.Page.LEVEL],
	[&"menu_settings", "Настройки", LevelMenu.Page.SETTINGS],
	[&"menu_exit", "Выход", -1],
]
const TAB_SIZE := 72

var tabs: Array[Button] = []
var _place: Label
var _tab_name: Label
var _exit_box: VBoxContainer
var _to_title: Button


func setup(menu: LevelMenu) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(48, 44)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.03, 0.035, 0.045, 0.88)
	plate.border_color = Color(0.55, 0.52, 0.47, 0.8)
	plate.set_border_width_all(1)
	plate.set_content_margin_all(18)
	add_theme_stylebox_override("panel", plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := menu._label(column, "Пауза", 30, LevelMenu.TEXT)
	title.add_theme_font_override("font", menu._serif_font)
	_place = menu._label(column, "", 15, LevelMenu.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for tab: Array in TABS:
		var button := menu._icon_button(row, ItemCatalog.icon(tab[0]), TAB_SIZE)
		button.tooltip_text = tab[1]
		button.focus_entered.connect(_show_name.bind(tab[1]))
		button.mouse_entered.connect(_show_name.bind(tab[1]))
		if tab[2] >= 0:
			button.pressed.connect(func() -> void: page_chosen.emit(tab[2]))
		else:
			button.pressed.connect(_toggle_exit)
		tabs.append(button)
	_tab_name = menu._label(column, "", 22, LevelMenu.BRONZE)
	_tab_name.add_theme_font_override("font", menu._serif_font)
	_exit_box = VBoxContainer.new()
	_exit_box.visible = false
	column.add_child(_exit_box)
	_to_title = menu._menu_button(_exit_box, "Выйти в главное меню", 22)
	_to_title.pressed.connect(func() -> void: exit_to_title.emit())
	var back := menu._menu_button(_exit_box, "Вернуться в игру", 22)
	back.pressed.connect(func() -> void: resume.emit())
	menu._label(column, "[E] выбрать    [Esc] вернуться", 15, LevelMenu.MUTED)


func open(place: String) -> void:
	_place.text = "Мир не ждёт · %s" % place
	_exit_box.visible = false
	tabs[0].grab_focus()
	_show_name(TABS[0][1])


## Раскрыт ли «Выход» — «Назад» сперва сворачивает его.
func exit_open() -> bool:
	return _exit_box.visible


func close_exit() -> void:
	_exit_box.visible = false
	tabs[tabs.size() - 1].grab_focus()


func _toggle_exit() -> void:
	_exit_box.visible = not _exit_box.visible
	if _exit_box.visible:
		_to_title.grab_focus()


func _show_name(text: String) -> void:
	_tab_name.text = text
