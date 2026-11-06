class_name StatusEffect
extends Resource
## Бафф или дебафф на герое (§8.12): значок под полосами HUD, зелёный треугольник вверх —
## бафф, красный вниз — дебафф. Сам эффект делает тот, кто его вешает (грязь — MudZone и Player);
## здесь — то, что видит игрок. Значок — ItemCatalog.icon(id).

const DIRECTORY := "res://data/effects"

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var positive := false


static func by_id(wanted: StringName) -> StatusEffect:
	var path := "%s/%s.tres" % [DIRECTORY, wanted]
	return load(path) as StatusEffect if ResourceLoader.exists(path) else null
