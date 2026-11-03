class_name Facet
extends Resource
## Грань — надеваемый осколок-модификатор (§8.6). Занимает слоты; надевается и снимается у осколка.
## Меняет числа героя через modifiers: ключ — параметр (см. PlayerStats.mod), значение — множитель.
## Часть граней зависит от возраста: «Лёгкость юности» слабеет с годами, «Тяжесть опыта» растёт.
## Способности, открывающие новые места, гранями не даются: их даёт мир и сюжет.

enum AgeCurve { NONE, YOUTH, EXPERIENCE }

const DIRECTORY := "res://data/facets"
## В этом возрасте возрастная грань достигает края: юность гаснет, опыт в полной силе.
const AGE_FULL := 40.0

## Он же id предмета в GameState: грань есть, если предмет найден.
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var cost := 1
@export var age_curve := AgeCurve.NONE
## Параметр → множитель при полной силе грани.
@export var modifiers := {}
## Значок; пусто — в меню только текст.
@export var icon: Texture2D


## Сила грани 0…1 в этом возрасте.
func strength(age: float) -> float:
	var t := clampf((age - PlayerStats.AGE_MIN) / (AGE_FULL - PlayerStats.AGE_MIN), 0.0, 1.0)
	match age_curve:
		AgeCurve.YOUTH: return 1.0 - t
		AgeCurve.EXPERIENCE: return t
	return 1.0


## Множитель параметра в этом возрасте; 1 — грань его не трогает.
func multiplier(key: StringName, age: float) -> float:
	return lerpf(1.0, modifiers.get(key, 1.0), strength(age))


## Все грани игры в порядке имён файлов.
static func catalog() -> Array[Facet]:
	var list: Array[Facet] = []
	for file in ResourceLoader.list_directory(DIRECTORY):
		if file.ends_with(".tres"):
			list.append(load("%s/%s" % [DIRECTORY, file]) as Facet)
	return list


static func by_id(wanted: StringName) -> Facet:
	for facet in catalog():
		if facet.id == wanted:
			return facet
	return null
