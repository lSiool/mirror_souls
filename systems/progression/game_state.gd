extends Node
## Состояние, которое переживает смерть и перезагрузку комнаты (§8.5):
## отзвуки, флаги мира, убитые враги, разбитое стекло, отзвук героя и активный осколок-чекпоинт.
## Всё это пишется на диск (save_game): игру можно закрыть и продолжить.

## Опыта на каждую ступень мастерства: обычный враг даёт около 1 (Dummy.mastery_xp).
const MASTERY_NEEDS: Array[float] = [50.0, 100.0, 175.0, 275.0, 400.0]
## Даже самый сильный враг: не меньше стольких убийств на ступень. Новое оружие не раскачать за минуту.
const MASTERY_MIN_KILLS := 15.0
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

const SAVED_FIELDS: Array[String] = ["echoes", "flags", "weapon_id", "checkpoint_room", "checkpoint_reality",
	"checkpoint_path", "killed", "broken_glass", "broken_forever", "hero_echo", "mastery", "weapon_glass", "items", "bow_id"]

## Отзвуки прошлого (рабочее название; в интерфейсе — «Отзвуки») — валюта и опыт:
## выпадают из врагов, лежат в сундуках; тратятся у зеркала на «прожитые годы».
var echoes := 0
var flags := {}
## Оружие в руке; пусто — герой пока безоружен.
var weapon_id: StringName
## Лук в руке (BOWS); пусто — обычный, без множителей.
var bow_id: StringName
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
	return data.get("extra", {})


func add_echoes(amount: int) -> void:
	echoes += amount
	Events.echoes_changed.emit(echoes)


## Смерть: половина отзвуков пропадает, вторая остаётся в отзвуке героя на месте гибели.
## Прежний, не подобранный отзвук исчезает вместе со своими отзвуками.
func drop_echoes(reality: StringName, at: Vector3, weapon: StringName, facing: float) -> void:
	var kept := echoes / 2
	hero_echo = {} if kept == 0 else {"reality": reality, "position": at, "amount": kept,
		"weapon": weapon, "facing": facing}
	echoes = 0
	Events.echoes_changed.emit(echoes)


## Герой коснулся своего отзвука: отзвуки возвращаются.
func take_hero_echo() -> void:
	var amount: int = hero_echo.get("amount", 0)
	hero_echo = {}
	add_echoes(amount)


## Мастерство: опыт типа оружия. Не больше доли ступени за раз (MASTERY_MIN_KILLS).
func add_mastery(type: StringName, xp: float) -> void:
	if type == &"" or xp <= 0.0:
		return
	var before := mastery_step(type)
	if before >= MASTERY_NEEDS.size():
		return
	mastery[type] = mastery_xp(type) + minf(xp, MASTERY_NEEDS[before] / MASTERY_MIN_KILLS)
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


func add_item(id: StringName) -> void:
	items[id] = item_count(id) + 1
	if BOWS.has(id):
		bow_id = id
		set_flag(&"has_bow")
	Events.item_found.emit(id)


func item_count(id: StringName) -> int:
	return items.get(id, 0)


func owned_bows() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in BOWS:
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
