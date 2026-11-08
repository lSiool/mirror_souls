extends Node
## Состояние, которое переживает смерть и перезагрузку комнаты (§8.5):
## отзвуки, флаги мира, убитые враги, разбитое стекло, отзвук героя и активный осколок-чекпоинт.
## Всё это пишется на диск (save_game): игру можно закрыть и продолжить.

## Очков мастерства на каждую ступень (Dummy.Rank: обычный враг 1, мини-босс 2, босс 5).
## Первая ступень — 20 врагов, вторая — ещё 30, всего 50. Дальше — черновик (100, 175, 275 всего).
const MASTERY_NEEDS: Array[float] = [20.0, 30.0, 50.0, 75.0, 100.0]
## Закалённое стекло: сколько материала и отзвуков стоит каждый шаг, прибавка урона за шаг.
const GLASS_ITEM: StringName = &"tempered_glass"
const GLASS_MATERIAL: Array[int] = [1, 1, 2, 2, 3]
const GLASS_ECHOES: Array[int] = [100, 250, 500, 900, 1500]
const GLASS_DAMAGE_STEP := 0.12
const SAVE_VERSION := 1
## Луки — два простых, разного происхождения: [название, натяжение ×, урон ×]. Подобранный — в руке.
const BOWS := {
	&"bow_hunter": ["охотничий лук", 0.8, 0.85],
	&"bow_guard": ["лук стражи", 1.2, 1.2],
}
## Оружие ближнего боя, которое герой носит с собой: в руке одно, сменить — у осколка.
const WEAPONS: Array[StringName] = [&"stick", &"sword", &"candlestick"]
## Щит-гоплон: продаёт кузнец часовни (§6.2).
const SHIELD_ITEM: StringName = &"shield_hoplon"

const SAVED_FIELDS: Array[String] = ["echoes", "flags", "weapon_id", "checkpoint_room", "checkpoint_reality",
	"checkpoint_path", "killed", "broken_glass", "broken_forever", "hero_echo", "mastery", "weapon_glass", "items", "bow_id",
	"second_weapon_id", "quick_slots", "arrow_slots", "active_arrow"]

## Отзвуки прошлого (рабочее название; в интерфейсе — «Отзвуки») — валюта и опыт:
## выпадают из врагов, лежат в сундуках; тратятся у зеркала на «прожитые годы».
var echoes := 0
var flags := {}
## Оружие в руке; пусто — герой пока безоружен.
var weapon_id: StringName
## Второй набор оружия «с собой» (§8.12): пока место под него — меняется у осколка,
## смена наборов в бою придёт позже. Пусто — второго набора нет.
var second_weapon_id: StringName
## Лук в руке (BOWS); пусто — обычный, без множителей.
var bow_id: StringName
## Крестовина расходников (§8.12): id в ячейках по порядку верх, лево, право, низ (клавиши 1–4).
## Пусто — ячейка пуста. Предмет лежит не больше чем в одной ячейке; кончился — ячейка его помнит.
const QUICK_SLOTS := 4
var quick_slots := [&"", &"", &"", &""]
## Стрелы (§6.2), как в Dark Souls: два гнезда лука, I и II; в каждом id особых стрел
## (data/arrows) или пусто — обычные, бесконечные. Что в гнёздах — выбирается у осколка,
## в бою «сменить стрелы» переключает active_arrow. Кончились особые — гнездо стреляет обычными.
const ARROW_SLOTS := 2
var arrow_slots := [&"", &""]
var active_arrow := 0
## Сохранять ли на диск (тесты отключают) и куда.
var saves_enabled := true
var save_path := "user://save.sav"
var checkpoint_room: StringName
var checkpoint_reality: StringName = &"normal"
## Путь к узлу точки возрождения относительно корня комнаты.
var checkpoint_path: NodePath = ^"Spawns/PlayerStart"
## Убитые враги по реальностям: {реальность: {путь в комнате: true}}. Переход через зеркало
## их не воскрешает; отдых у осколка и смерть героя — воскрешают, как в Souls.
var killed := {}
## Разбитое стекло по реальностям, так же {реальность: {путь: true}}: до отдыха — как враги,
## навсегда — панели с сундуком или тайником (их отдых не трогает).
var broken_glass := {}
var broken_forever := {}
## Отзвук героя на месте последней гибели: {reality, position, amount, weapon, facing}; пусто — нет.
var hero_echo := {}
## Опыт мастерства по типам оружия и шаги закалки по предметам.
var mastery := {}
var weapon_glass := {}
## Редкие предметы и грани: {id: сколько}. Смерть их не отнимает. Часть граней есть с начала.
var items := {&"facet_youth": 1, &"facet_experience": 1, &"facet_sole": 1, &"facet_grip": 1,
	&"facet_breath": 1, &"facet_eye": 1, &"facet_sip": 1}


## Начальные значения всего, что пишется в сохранение: «Новая игра» после выхода в главное
## меню начинает с них, а не с мира прошлой игры (автозагрузка живёт, пока открыта игра).
var _defaults := {}


func _ready() -> void:
	for key: String in SAVED_FIELDS:
		var value: Variant = get(key)
		_defaults[key] = value.duplicate(true) if value is Array or value is Dictionary else value


## Новая игра: всё, что пишется в сохранение, — как в начале.
func reset() -> void:
	for key: String in SAVED_FIELDS:
		var value: Variant = _defaults[key]
		set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	Events.echoes_changed.emit(echoes)
	Events.quick_items_changed.emit()
	Events.arrows_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Записать мир; extra — то, что знает менеджер: где стоит герой и его параметры.
func save_game(extra: Dictionary) -> void:
	if not saves_enabled:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить игру: %s" % save_path)
		return
	var data := {}
	for key: String in SAVED_FIELDS:
		data[key] = get(key)
	data["version"] = SAVE_VERSION
	data["extra"] = extra
	file.store_string(var_to_str(data))


## Прочитать мир. Возвращает extra из сохранения; пусто — читать нечего.
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var data: Variant = str_to_var(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version", 0) != SAVE_VERSION:
		push_warning("Сохранение не прочитано: %s" % save_path)
		return {}
	for key: String in SAVED_FIELDS:
		if data.has(key):
			set(key, data[key])
	Events.echoes_changed.emit(echoes)
	Events.quick_items_changed.emit()
	Events.arrows_changed.emit()
	return data.get("extra", {})


func add_echoes(amount: int) -> void:
	echoes += amount
	Events.echoes_changed.emit(echoes)


## Смерть: все отзвуки остаются в отзвуке героя на месте гибели.
## Прежний, не подобранный отзвук исчезает вместе со своими отзвуками.
func drop_echoes(reality: StringName, at: Vector3, weapon: StringName, facing: float) -> void:
	var kept := echoes
	hero_echo = {} if kept == 0 else {"reality": reality, "position": at, "amount": kept,
		"weapon": weapon, "facing": facing}
	echoes = 0
	Events.echoes_changed.emit(echoes)


## Герой коснулся своего отзвука: отзвуки возвращаются.
func take_hero_echo() -> void:
	var amount: int = hero_echo.get("amount", 0)
	hero_echo = {}
	add_echoes(amount)


## Мастерство: очки типа оружия.
func add_mastery(type: StringName, xp: float) -> void:
	if type == &"" or xp <= 0.0:
		return
	var before := mastery_step(type)
	if before >= MASTERY_NEEDS.size():
		return
	mastery[type] = mastery_xp(type) + xp
	var after := mastery_step(type)
	if after > before:
		Events.mastery_step_reached.emit(type, after)


func mastery_xp(type: StringName) -> float:
	return mastery.get(type, 0.0)


## Ступень 0…5.
func mastery_step(type: StringName) -> int:
	var left := mastery_xp(type)
	for i in MASTERY_NEEDS.size():
		if left < MASTERY_NEEDS[i]:
			return i
		left -= MASTERY_NEEDS[i]
	return MASTERY_NEEDS.size()


## Опыт внутри текущей ступени: (сколько набрано, сколько нужно); на последней — (0, 0).
func mastery_progress(type: StringName) -> Vector2:
	var step := mastery_step(type)
	if step >= MASTERY_NEEDS.size():
		return Vector2.ZERO
	var left := mastery_xp(type)
	for i in step:
		left -= MASTERY_NEEDS[i]
	return Vector2(left, MASTERY_NEEDS[step])


func glass_level(weapon_id: StringName) -> int:
	return weapon_glass.get(weapon_id, 0)


## Множитель урона от закалённого стекла.
func glass_damage_mult(weapon_id: StringName) -> float:
	return 1.0 + glass_level(weapon_id) * GLASS_DAMAGE_STEP


## Закалить оружие: хватает материала и отзвуков — шаг сделан.
func temper(weapon_id: StringName) -> bool:
	var level := glass_level(weapon_id)
	if level >= GLASS_MATERIAL.size() or item_count(GLASS_ITEM) < GLASS_MATERIAL[level] or echoes < GLASS_ECHOES[level]:
		return false
	items[GLASS_ITEM] = item_count(GLASS_ITEM) - GLASS_MATERIAL[level]
	add_echoes(-GLASS_ECHOES[level])
	weapon_glass[weapon_id] = level + 1
	return true


func add_item(id: StringName, count := 1) -> void:
	items[id] = item_count(id) + count
	if BOWS.has(id):
		bow_id = id
		set_flag(&"has_bow")
	if is_consumable(id):
		# Новый расходник сам ложится в первую пустую ячейку, как в кармане Elden Ring.
		if not quick_slots.has(id) and quick_slots.has(&""):
			quick_slots[quick_slots.find(&"")] = id
		Events.quick_items_changed.emit()
	if is_arrow(id):
		# Новые стрелы сами ложатся в пустое гнездо — сперва во второе: первое для обычных.
		if not arrow_slots.has(id):
			for slot in [1, 0]:
				if arrow_slots[slot] == &"":
					arrow_slots[slot] = id
					break
		Events.arrows_changed.emit()
	Events.item_found.emit(id)


## Боевой расходник (data/consumables): его можно положить в крестовину и бросить.
func is_consumable(id: StringName) -> bool:
	return ConsumableData.by_id(id) != null


## Особые стрелы (data/arrows): ложатся в гнездо лука, а не в крестовину.
func is_arrow(id: StringName) -> bool:
	return ArrowData.by_id(id) != null


## Чем стреляет лук сейчас: особые стрелы активного гнезда или пусто — обычные.
func current_arrow() -> StringName:
	var id: StringName = arrow_slots[active_arrow]
	return id if item_count(id) > 0 else &""


## Кнопка «сменить стрелы»: другое гнездо.
func swap_arrows() -> void:
	active_arrow = (active_arrow + 1) % ARROW_SLOTS
	Events.arrows_changed.emit()


## Положить стрелы в гнездо 0…1 (у осколка); из другого гнезда они уходят. Пусто — обычные.
func set_arrow_slot(slot: int, id: StringName) -> void:
	if slot < 0 or slot >= ARROW_SLOTS:
		return
	if id != &"" and arrow_slots.has(id):
		arrow_slots[arrow_slots.find(id)] = &""
	arrow_slots[slot] = id
	Events.arrows_changed.emit()


## Какие особые стрелы есть у героя (для выбора у осколка).
func owned_arrows() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in items:
		if item_count(id) > 0 and is_arrow(id):
			result.append(id)
	return result


## Положить расходник в ячейку 0…3; из прежней ячейки он уходит. Пустой id — очистить ячейку.
func set_quick_slot(slot: int, id: StringName) -> void:
	if slot < 0 or slot >= QUICK_SLOTS:
		return
	if id != &"":
		var was := quick_slots.find(id)
		if was >= 0:
			quick_slots[was] = &""
	quick_slots[slot] = id
	Events.quick_items_changed.emit()


func quick_item(slot: int) -> StringName:
	return quick_slots[slot] if slot >= 0 and slot < QUICK_SLOTS else &""


func item_count(id: StringName) -> int:
	return items.get(id, 0)


func owned_bows() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in BOWS:
		if item_count(id) > 0:
			result.append(id)
	return result


## Оружие взято в руку — теперь оно у героя с собой. Без надписи: её показывает находка.
func own_weapon(id: StringName) -> void:
	if WEAPONS.has(id) and item_count(id) == 0:
		items[id] = 1


func owned_weapons() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in WEAPONS:
		if item_count(id) > 0:
			result.append(id)
	return result


func bow_draw_mult() -> float:
	return BOWS[bow_id][1] if BOWS.has(bow_id) else 1.0


func bow_damage_mult() -> float:
	return BOWS[bow_id][2] if BOWS.has(bow_id) else 1.0


## Потратить один предмет; false — его нет.
func take_item(id: StringName) -> bool:
	if item_count(id) <= 0:
		return false
	items[id] = item_count(id) - 1
	if quick_slots.has(id):
		Events.quick_items_changed.emit()
	if arrow_slots.has(id):
		Events.arrows_changed.emit()
	return true


func set_flag(id: StringName, value := true) -> void:
	flags[id] = value


func has_flag(id: StringName) -> bool:
	return flags.get(id, false)


func set_checkpoint(room: StringName, reality: StringName, path: NodePath) -> void:
	checkpoint_room = room
	checkpoint_reality = reality
	checkpoint_path = path


func mark_killed(reality: StringName, path: NodePath) -> void:
	_mark(killed, reality, path)


func killed_in(reality: StringName) -> Array:
	return killed.get(reality, {}).keys()


func mark_glass(reality: StringName, path: NodePath, forever: bool) -> void:
	_mark(broken_forever if forever else broken_glass, reality, path)


func broken_glass_in(reality: StringName) -> Array:
	return broken_glass.get(reality, {}).keys() + broken_forever.get(reality, {}).keys()


## Отдых у осколка или смерть героя: враги оживают, скаты и панели с засадой снова целы.
func restore_world() -> void:
	killed.clear()
	broken_glass.clear()


func _mark(table: Dictionary, reality: StringName, path: NodePath) -> void:
	if not table.has(reality):
		table[reality] = {}
	table[reality][path] = true
