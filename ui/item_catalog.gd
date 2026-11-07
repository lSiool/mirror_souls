class_name ItemCatalog
## Названия, значки и разделы предметов для интерфейса (§8.12): окно находки, «Предметы», HUD.
## Значок — файл assets/ui/icons/<id>.svg (или .png): заменить стиль — заменить файлы, код не меняется.
## Грани берут имя из Facet, оружие — из своего .tres, если здесь имени нет.

enum Kind { WEAPON, CONSUMABLE, MATERIAL, RECIPE, KEY, NOTE }

const ICONS_DIR := "res://assets/ui/icons/"
const KIND_NAMES := {Kind.WEAPON: "Оружие", Kind.CONSUMABLE: "Расходники", Kind.MATERIAL: "Материалы",
	Kind.RECIPE: "Рецепты", Kind.KEY: "Ключевые", Kind.NOTE: "Записки"}
## id → [название, раздел, описание].
const ITEMS := {
	&"stick": ["Брусок", Kind.WEAPON, "Крепкое полено из поленницы у хижины. Бьёт как меч, но слабее."],
	&"sword": ["Меч", Kind.WEAPON, "Меч от кузнеца часовни. Быстрый, режет; мастеру — кровотечение."],
	&"candlestick": ["Подсвечник", Kind.WEAPON, "Тяжёлый подсвечник мародёра. Молот низкого качества: бьёт слабее, но теми же ударами."],
	&"shield_hoplon": ["Щит-гоплон", Kind.WEAPON, "Старый, но удар держит. Парирует сразу; блок им дешевле."],
	&"bow_hunter": ["Охотничий лук", Kind.WEAPON, "Лёгкий лук: натягивается быстро, бьёт слабее."],
	&"bow_guard": ["Лук стражи", Kind.WEAPON, "Тугой лук: натягивать дольше, стрела бьёт сильнее."],
	&"has_bow": ["Лук", Kind.WEAPON, "Простой лук."],
	&"throwing_knife": ["Метательный нож", Kind.CONSUMABLE, "Летит почти прямо и быстро. Ранит слабо, зато не будит всю округу. Сильнее в ловкой руке."],
	&"throwing_axe": ["Метательный топорик", Kind.CONSUMABLE, "Летит дугой, кувыркаясь. Тяжёлый: бьёт больно и сбивает стойкость."],
	&"fire_flask": ["Огненная склянка", Kind.CONSUMABLE, "Бросается навесом и разбивается вспышкой огня: задевает всех рядом."],
	&"flask_vessel": ["Второй глоток зелья", Kind.KEY, "У лечебного зелья стало на глоток больше."],
	&"flask_potency": ["Крепкое зелье Травницы", Kind.KEY, "Травница сделала зелье крепче."],
	&"tempered_glass": ["Закалённое стекло", Kind.MATERIAL, "Редкий материал. У осколка закаляет оружие."],
	&"clear_glass": ["Чистое стекло", Kind.MATERIAL, "Освобождает вложенные очки характеристик. Возраст не возвращает."],
	&"facet_slot": ["Слот для граней", Kind.KEY, "Ещё одна грань поместится на героя."],
	&"recipe_heavy_hammer": ["Рецепт: тяжёлый молот", Kind.RECIPE, "Выкует кузнец часовни."],
	&"boss_smith_echo": ["Отзвук Безмолвного Кузнеца", Kind.KEY, "Память о старом кузнеце. Тяжёлая, как его молот."],
}
## Зелье — не предмет GameState.items, но в «Расходниках» и HUD оно есть.
const FLASK := &"flask"


static func display_name(id: StringName) -> String:
	if ITEMS.has(id):
		return ITEMS[id][0]
	var facet := Facet.by_id(id)
	if facet:
		return facet.display_name
	if ResourceLoader.exists("res://data/weapons/%s.tres" % id):
		return WeaponData.by_id(id).display_name
	return String(id)


static func description(id: StringName) -> String:
	if ITEMS.has(id):
		return ITEMS[id][2]
	var facet := Facet.by_id(id)
	return facet.description if facet else ""


static func kind(id: StringName) -> Kind:
	return ITEMS[id][1] if ITEMS.has(id) else Kind.KEY


## Значок предмета, грани или эффекта; нет файла — общий «неизвестный».
static func icon(id: StringName) -> Texture2D:
	var facet := Facet.by_id(id) if String(id).begins_with("facet_") else null
	if facet and facet.icon:
		return facet.icon
	for ext in ["png", "svg"]:
		var path := "%s%s.%s" % [ICONS_DIR, id, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return load(ICONS_DIR + "unknown.svg")


## Что лежит в разделе: id предметов, которые есть у героя.
static func owned(of_kind: Kind) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in ITEMS:
		if ITEMS[id][1] == of_kind and GameState.item_count(id) > 0 and id != &"has_bow":
			result.append(id)
	return result
