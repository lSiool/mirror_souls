class_name PlayerStats
extends Resource
## Все числа героя в одном месте (§1.3). Часть из них зависит от возраста:
## младше — быстрее и ловчее, старше — чуть медленнее, но удар сильнее.
## Возраст — стартовый плюс прожитое: каждый уровень старит героя (§8.6), тело меняется
## по той же кривой до планок. Параметры растут от вложенных очков, тоже до потолка.

const AGE_MIN := 14
const AGE_MAX := 22
## Каждый уровень старит на столько лет; после AGING_LEVELS возраст больше не растёт,
## а уровни по-прежнему дают параметры.
const YEARS_PER_LEVEL := 0.25
const AGING_LEVELS := 120

enum Param { HEALTH, STAMINA, STRENGTH, DEXTERITY }

## Слотов для граней с самого начала; ещё — от находок в мире.
const BASE_FACET_SLOTS := 3

@export_range(AGE_MIN, AGE_MAX) var age := 17:
	set(value):
		age = clampi(value, AGE_MIN, AGE_MAX)
		emit_changed()

@export_group("Зависит от возраста (14 → 22, дальше — до планок)")
@export var move_speed_young := 7.4
@export var move_speed_old := 7.0
@export var acceleration_young := 62.0
@export var acceleration_old := 56.0
@export var jump_velocity_young := 11.6
@export var jump_velocity_old := 11.1
@export var roll_speed_young := 11.0
@export var roll_speed_old := 10.4
@export var roll_iframes_young := 0.32
@export var roll_iframes_old := 0.28
@export var sword_damage_young := 20.0
@export var sword_damage_old := 22.0
## Планки тела: доля от значений 14-летнего, ниже (урон — выше) возраст не уведёт.
## Прыжок — самая строгая: уровни проектируем под самого старшего героя.
@export var move_speed_limit := 0.88
@export var acceleration_limit := 0.85
@export var jump_velocity_limit := 0.93
@export var roll_speed_limit := 0.88
@export var roll_iframes_limit := 0.75
@export var sword_damage_limit := 1.4

@export_group("Уровень")
## Потолок прибавки от параметра; очки подходят к нему всё медленнее (мягкая планка).
@export var health_bonus_cap := 200.0
@export var stamina_bonus_cap := 100.0
## Прибавка к урону, доля: 1.5 — плюс 150 %.
@export var strength_bonus_cap := 1.5
@export var dexterity_bonus_cap := 1.5
## Сколько очков даёт около 63 % потолка.
@export var bonus_softness := 40.0

@export_group("Движение")
@export var gravity := 32.0
@export var fall_multiplier := 1.45
@export var jump_cut_multiplier := 2.2
@export var max_fall_speed := 24.0
@export var air_acceleration := 34.0
@export var friction := 55.0
## Насколько медленно гаснет скорость выше обычной (импульс со ската).
@export var momentum_decay := 9.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var input_buffer := 0.15
## Буфер удара длиннее: комбо легко нажимать.
@export var attack_buffer := 0.25
## Как быстро гаснет скорость в воздухе без ввода: импульс со ската доносится до боя.
@export var air_drag := 6.0
@export var roll_duration := 0.42

@export_group("Уступы")
## Край выше ног на столько — герой повисает на руках; ниже — сразу подтягивается.
@export var ledge_hang_min := 1.2
@export var ledge_hang_max := 2.1
## Ниже этого край не ловим: на него просто наступают.
@export var ledge_vault_min := 0.25
## Ловим край только около вершины прыжка или в падении.
@export var ledge_max_rise := 2.0
## Длина рук до края: на сколько ноги висящего ниже края.
@export var ledge_hang_depth := 1.75
@export var ledge_climb_time := 0.25
## Задержка перед подтягиванием, если в прыжке держали «к краю»: видно, что герой повис.
@export var ledge_auto_climb_delay := 0.12
@export var ledge_regrab_cooldown := 0.3
## Провалился сквозь стекло — столько секунд не успевает схватиться за край:
## стекло-ловушка над ямой остаётся ловушкой.
@export var ledge_fall_through_block := 0.8

@export_group("Стекло")
@export var slide_gravity_scale := 0.65
@export var slide_steer := 10.0
@export var max_slide_speed := 15.0
@export var climb_speed := 3.6
@export var climb_slip := 0.6
@export var wall_jump_push := 6.5
@export var mantle_velocity := 7.0

@export_group("Бой")
@export var base_health := 100.0
@export var base_stamina := 100.0
@export var stamina_regen := 40.0
@export var stamina_regen_delay := 0.5
@export var roll_cost := 22.0
@export var attack_cost := 14.0
@export var attack_lunge := 2.5
@export var plunge_speed := 20.0
@export var hurt_iframes := 0.7
## Падение: до этой высоты (м, от верхней точки полёта) — без урона. Прыжок — около 2.1 м.
@export var fall_safe_height := 7.0
## С этой высоты падение смертельно. Смертельно только «срезать» карту прыжком вниз.
@export var fall_lethal_height := 28.0
## Как растёт урон между безопасной и смертельной высотой: доля пути в этой степени.
## 2 — чуть выше безопасной почти царапина, середина — четверть здоровья; 1.5 — середина — 35 %.
@export var fall_damage_power := 1.5

@export_group("Зелье")
## Глотков лечебного зелья; пополняются при отдыхе у осколка.
@export var flask_charges := 2
## Доля здоровья за глоток.
@export var flask_heal := 0.6
## Сколько секунд пьёт; лечит в момент глотка — на этой доле времени. Ударили раньше — пролил.
@export var flask_drink_time := 0.9
@export var flask_sip_at := 0.55
## Пока пьёт — идёт шагом.
@export var flask_move_mult := 0.3

@export_group("Защита")
## Окно парирования после нажатия блока.
@export var parry_window := 0.23
## Сколько выносливости стоит принятый на блок удар: урон × множитель.
@export var block_stamina_mult := 1.0
@export var block_move_mult := 0.35
## В блоке выносливость восстанавливается медленнее.
@export var block_regen_mult := 0.4
@export var guard_break_time := 0.8

@export_group("Лук")
## За сколько секунд лук натягивается полностью.
@export var bow_draw_time := 0.6
@export var bow_speed_min := 18.0
@export var bow_speed_max := 32.0
@export var bow_damage_min := 8.0
@export var bow_damage_max := 18.0
@export var bow_poise_min := 6.0
@export var bow_poise_max := 14.0
@export var bow_cost := 10.0
@export var bow_move_mult := 0.3
## Угол прицела вверх (с «вверх») и вниз (с «вниз» в воздухе), градусы.
@export var aim_up_angle := 70.0
@export var aim_down_angle := 30.0

@export_group("Особые удары")
## Сколько секунд держать удар после взмаха, чтобы зарядить.
@export var charge_time := 0.55
@export var charge_move_mult := 0.3
## Сколько после принятого на блок удара можно ответить контрударом.
@export var counter_window := 0.45
@export var riposte_range := 1.8
@export var backstab_range := 1.6
## Сколько после выхода из скольжения ещё срабатывает удар из скольжения.
@export var slide_attack_window := 0.25
## Сколько после кувырка ещё срабатывает удар после кувырка.
@export var roll_attack_window := 0.3

var level := 0
## Очки по параметрам (Param → сколько вложено) и свободные — после перераспределения.
var points := {}
var unspent := 0
## Надетые грани.
var facets: Array[Facet] = []

var current_age: float:
	get: return age_at(level)
var max_health: float:
	get: return (base_health + bonus_with(Param.HEALTH, 0)) * facet_mult(&"max_health")
var max_stamina: float:
	get: return (base_stamina + bonus_with(Param.STAMINA, 0)) * facet_mult(&"max_stamina")
## Множитель урона лука от меткости.
var bow_damage_mult: float:
	get: return (1.0 + bonus_with(Param.DEXTERITY, 0)) * facet_mult(&"bow_damage")

var move_speed: float:
	get: return speed_at(current_age) * facet_mult(&"move_speed")
var acceleration: float:
	get: return _by_age(current_age, acceleration_young, acceleration_old, acceleration_limit)
var jump_velocity: float:
	get: return jump_at(current_age)
var roll_speed: float:
	get: return _by_age(current_age, roll_speed_young, roll_speed_old, roll_speed_limit)
var roll_iframes: float:
	get: return iframes_at(current_age) * facet_mult(&"roll_iframes")
var sword_damage: float:
	get: return damage_at(current_age) * (1.0 + bonus_with(Param.STRENGTH, 0)) * facet_mult(&"damage")


## Возраст на таком уровне: стартовый плюс прожитое, после AGING_LEVELS не растёт.
func age_at(at_level: int) -> float:
	return age + mini(at_level, AGING_LEVELS) * YEARS_PER_LEVEL


func speed_at(at_age: float) -> float:
	return _by_age(at_age, move_speed_young, move_speed_old, move_speed_limit)


func jump_at(at_age: float) -> float:
	return _by_age(at_age, jump_velocity_young, jump_velocity_old, jump_velocity_limit)


func iframes_at(at_age: float) -> float:
	return _by_age(at_age, roll_iframes_young, roll_iframes_old, roll_iframes_limit)


func damage_at(at_age: float) -> float:
	return _by_age(at_age, sword_damage_young, sword_damage_old, sword_damage_limit)


## Цена следующего уровня в отзвуках.
func level_cost() -> int:
	return 60 + 12 * level + int(0.4 * level * level)


## Новый уровень: очко в параметр и прожитые годы. Отзвуки списывает тот, кто вызывает.
func level_up(param: Param) -> void:
	level += 1
	add_point(param)


func add_point(param: Param) -> void:
	points[param] = points_in(param) + 1
	emit_changed()


## Свободное очко после перераспределения: без отзвуков и без новых лет.
func spend_unspent(param: Param) -> void:
	if unspent > 0:
		unspent -= 1
		add_point(param)


func points_in(param: Param) -> int:
	return points.get(param, 0)


## Чистое стекло: все очки снова свободны, прожитые годы остаются (§8.6).
func respec() -> void:
	for value: int in points.values():
		unspent += value
	points.clear()
	emit_changed()


## Общий множитель надетых граней на параметр в нынешнем возрасте.
func facet_mult(key: StringName) -> float:
	var result := 1.0
	for facet in facets:
		result *= facet.multiplier(key, current_age)
	return result


## Параметр без своего геттера с учётом граней: stats.mod(&"climb_speed", stats.climb_speed).
func mod(key: StringName, value: float) -> float:
	return value * facet_mult(key)


func facet_slots_used() -> int:
	var used := 0
	for facet in facets:
		used += facet.cost
	return used


## Надеть или снять. false — не хватило слотов из total.
func toggle_facet(facet: Facet, total: int) -> bool:
	if facet in facets:
		facets.erase(facet)
	elif facet_slots_used() + facet.cost <= total:
		facets.append(facet)
	else:
		return false
	emit_changed()
	return true


## Опыт мастерства за убийство растёт с уровнем героя: взрослому отдача больше (§8.6).
func mastery_rate() -> float:
	return 1.0 + level / 60.0


## Вернуть героя к началу: для отладки и тестов.
func reset_progress() -> void:
	level = 0
	unspent = 0
	points.clear()
	facets.clear()
	emit_changed()


## Прибавка параметра, если вложить ещё extra очков: быстро вначале, у потолка — едва заметно.
func bonus_with(param: Param, extra: int) -> float:
	var cap: float
	match param:
		Param.HEALTH: cap = health_bonus_cap
		Param.STAMINA: cap = stamina_bonus_cap
		Param.STRENGTH: cap = strength_bonus_cap
		_: cap = dexterity_bonus_cap
	return cap * (1.0 - exp(-float(points_in(param) + extra) / bonus_softness))


## Значение по возрасту: та же прямая 14 → 22 продолжается дальше, но не за планку.
func _by_age(at_age: float, young: float, old: float, limit: float) -> float:
	var value := lerpf(young, old, (at_age - AGE_MIN) / float(AGE_MAX - AGE_MIN))
	var bound := young * limit
	return maxf(value, bound) if old < young else minf(value, bound)
