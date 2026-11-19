class_name ArmorData
extends Resource
## Доспех (§8.6, броня — черновик): в какую ячейку надевается и от чего защищает. Сопротивления — доли урона,
## которые доспех снимает (0.25 — четверть); надетое складывается, но не больше MAX_RESIST. Пока — болванки
## для проверки механики (огонь лавы, §8.13); вес, физическая защита и вид на герое — позже.

const DIRECTORY := "res://data/armor"
## Больше этого надетое не защищает: даже в лучшей броне лава жжёт.
const MAX_RESIST := 0.9
const SLOTS: Array[StringName] = [&"head", &"body", &"hands", &"legs"]

## Ячейка: head, body, hands, legs.
@export var slot: StringName = &"body"
## Вид урона → доля, которую снимает доспех: {&"fire": 0.25}.
@export var resist := {}


static func by_id(wanted: StringName) -> ArmorData:
	if wanted == &"":
		return null
	var path := "%s/%s.tres" % [DIRECTORY, wanted]
	return load(path) as ArmorData if ResourceLoader.exists(path) else null
