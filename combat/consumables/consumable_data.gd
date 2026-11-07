class_name ConsumableData
extends Resource
## Боевой расходник (§6.2, §8.12): то, что лежит в ячейке крестовины и бросается кнопкой ячейки.
## Нож летит почти прямо, топорик — круче и тяжелее, склянка — навесом и разбивается вспышкой огня.
## Броски без указателя траектории (журнал 2026-10-24). Урон растёт от ловкости (PlayerStats.throw_damage_mult).
## Имя, раздел и описание — в ItemCatalog, значок — assets/ui/icons/<id>.svg; сколько есть — GameState.items.

const DIRECTORY := "res://data/consumables"

@export var id: StringName
## Скорость броска, м/с, и угол над горизонталью вперёд, градусы.
@export var speed := 16.0
@export var angle := 0.0
@export var gravity := 9.0
@export var damage := 12.0
@export var poise_damage := 10.0
@export var knockback := 3.0
@export var stamina_cost := 8.0
## Бросок: на какой секунде предмет вылетает из руки и сколько длится весь бросок.
@export var release_at := 0.14
@export var duration := 0.36
## Вращение в полёте, оборотов в секунду (топорик кувыркается); 0 — летит остриём вперёд.
@export var spin := 0.0
## Склянка: радиус вспышки, когда она разбивается обо что угодно; 0 — не разбивается.
@export var burst_radius := 0.0
@export var burst_color := Color(1.0, 0.55, 0.2)
## Вид заглушки в руке и в полёте: брусок (нож, топорик) или шар (склянка — при burst_radius > 0).
@export var look_size := Vector3(0.3, 0.05, 0.05)
@export var look_color := Color(0.8, 0.82, 0.86)
@export var look_metal := true


static func by_id(wanted: StringName) -> ConsumableData:
	if wanted == &"":
		return null
	var path := "%s/%s.tres" % [DIRECTORY, wanted]
	return load(path) as ConsumableData if ResourceLoader.exists(path) else null
