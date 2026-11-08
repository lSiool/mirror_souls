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

## Что склянка оставляет после себя (§6.2): огненную лужу, ядовитое облако, кислоту, свет, смолу.
enum Zone { NONE, FIRE, POISON, ACID, HOLY, TAR }
@export_group("Склянка")
@export var zone := Zone.NONE
## Размер зоны: полуширина лужи или радиус облака, м; и сколько она держится, с.
@export var zone_radius := 0.0
@export var zone_time := 0.0
## Сколько держится состояние на задетом (горение, яд, «разъедено», смола), с.
@export var status_time := 0.0
## Святая склянка: во сколько раз больнее нежити (Dummy.unholy).
@export var holy_mult := 1.0
## Задержка броска: держишь кнопку ячейки — рука отводится дальше, полный заряд — скорость ×это.
## 1 — заряда нет (нож и топорик).
@export var charge_speed_mult := 1.0
@export_group("")
## Вид заглушки в руке и в полёте: брусок (нож, топорик) или шар (склянка — при burst_radius > 0).
@export var look_size := Vector3(0.3, 0.05, 0.05)
@export var look_color := Color(0.8, 0.82, 0.86)
@export var look_metal := true


static func by_id(wanted: StringName) -> ConsumableData:
	if wanted == &"":
		return null
	var path := "%s/%s.tres" % [DIRECTORY, wanted]
	return load(path) as ConsumableData if ResourceLoader.exists(path) else null
