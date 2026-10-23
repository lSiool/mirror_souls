class_name PlayerStats
extends Resource
## Все числа героя в одном месте (§1.3). Часть из них зависит от стартового возраста:
## младше — быстрее и ловчее, старше — чуть медленнее, но удар сильнее.
## Разница между краями диапазона — единицы процентов.

const AGE_MIN := 14
const AGE_MAX := 22

@export_range(AGE_MIN, AGE_MAX) var age := 17:
	set(value):
		age = clampi(value, AGE_MIN, AGE_MAX)
		emit_changed()

@export_group("Зависит от возраста (14 → 22)")
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
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_regen := 40.0
@export var stamina_regen_delay := 0.5
@export var roll_cost := 22.0
@export var attack_cost := 14.0
@export var attack_lunge := 2.5
@export var plunge_speed := 20.0
@export var hurt_iframes := 0.7
## Падение: до этой высоты (м, от верхней точки полёта) — без урона. Прыжок — около 2.1 м.
@export var fall_safe_height := 7.0
## С этой высоты падение смертельно. Между — урон растёт по квадрату: чуть выше безопасной —
## царапина, половина пути — четверть здоровья. Смертельно только «срезать» карту прыжком вниз.
@export var fall_lethal_height := 28.0

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
@export var riposte_range := 1.8
@export var backstab_range := 1.6
## Сколько после выхода из скольжения ещё срабатывает удар из скольжения.
@export var slide_attack_window := 0.25
## Сколько после кувырка ещё срабатывает удар после кувырка.
@export var roll_attack_window := 0.3

var move_speed: float:
	get: return _by_age(move_speed_young, move_speed_old)
var acceleration: float:
	get: return _by_age(acceleration_young, acceleration_old)
var jump_velocity: float:
	get: return _by_age(jump_velocity_young, jump_velocity_old)
var roll_speed: float:
	get: return _by_age(roll_speed_young, roll_speed_old)
var roll_iframes: float:
	get: return _by_age(roll_iframes_young, roll_iframes_old)
var sword_damage: float:
	get: return _by_age(sword_damage_young, sword_damage_old)


func _by_age(young: float, old: float) -> float:
	var t := float(age - AGE_MIN) / float(AGE_MAX - AGE_MIN)
	return lerpf(young, old, t)
