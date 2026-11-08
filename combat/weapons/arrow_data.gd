class_name ArrowData
extends Resource
## Особые стрелы (§6.2): как в Dark Souls, у лука два гнезда стрел — I и II (GameState.arrow_slots).
## Что лежит в гнёздах, выбирается у осколка; в бою кнопка «сменить стрелы» переключает
## гнездо. Обычные стрелы бесконечны и ресурса не имеют — они стоят в пустом гнезде
## и там, где особые кончились. Сколько особых есть — GameState.items; имя — ItemCatalog.

const DIRECTORY := "res://data/arrows"

@export var id: StringName
@export var damage_mult := 1.0
## Что вешает на врага при попадании (Statuses: горение, яд…), на сколько секунд.
@export var status: StringName
@export var status_time := 0.0
## Поджигает смолу там, куда воткнулась (и на враге — через горение).
@export var ignites := false
## Горит ли наконечник (Flame) и цвет его света.
@export var flame := false
@export var tip_color := Color(0.8, 0.82, 0.86)


static func by_id(wanted: StringName) -> ArrowData:
	if wanted == &"":
		return null
	var path := "%s/%s.tres" % [DIRECTORY, wanted]
	return load(path) as ArrowData if ResourceLoader.exists(path) else null
