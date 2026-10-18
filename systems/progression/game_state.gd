extends Node
## Состояние, которое переживает смерть и перезагрузку комнаты (§8.5):
## валюта, флаги мира и активный осколок-чекпоинт.

var currency := 0
var flags := {}
var checkpoint_reality: StringName = &"normal"
## Путь к узлу точки возрождения относительно корня комнаты.
var checkpoint_path: NodePath = ^"Spawns/PlayerStart"


func add_currency(amount: int) -> void:
	currency += amount
	Events.currency_changed.emit(currency)


func set_flag(id: StringName, value := true) -> void:
	flags[id] = value


func has_flag(id: StringName) -> bool:
	return flags.get(id, false)


func set_checkpoint(reality: StringName, path: NodePath) -> void:
	checkpoint_reality = reality
	checkpoint_path = path
