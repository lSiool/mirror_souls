extends Node
## Состояние, которое переживает смерть и перезагрузку комнаты (§8.5):
## отзвуки, флаги мира, убитые враги, отзвук героя и активный осколок-чекпоинт.

## Отзвуки прошлого (рабочее название; в интерфейсе — «Отзвуки») — валюта и опыт:
## выпадают из врагов, лежат в сундуках; тратятся у зеркала на «прожитые годы».
var echoes := 0
var flags := {}
var checkpoint_reality: StringName = &"normal"
## Путь к узлу точки возрождения относительно корня комнаты.
var checkpoint_path: NodePath = ^"Spawns/PlayerStart"
## Убитые враги по реальностям: {реальность: {путь в комнате: true}}. Переход через зеркало
## их не воскрешает; отдых у осколка и смерть героя — воскрешают, как в Souls.
var killed := {}
## Отзвук героя на месте последней гибели: {reality, position, amount, weapon, facing}; пусто — нет.
var hero_echo := {}


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


func set_flag(id: StringName, value := true) -> void:
	flags[id] = value


func has_flag(id: StringName) -> bool:
	return flags.get(id, false)


func set_checkpoint(reality: StringName, path: NodePath) -> void:
	checkpoint_reality = reality
	checkpoint_path = path


func mark_killed(reality: StringName, path: NodePath) -> void:
	if not killed.has(reality):
		killed[reality] = {}
	killed[reality][path] = true


func killed_in(reality: StringName) -> Array:
	return killed.get(reality, {}).keys()


func revive_enemies() -> void:
	killed.clear()
