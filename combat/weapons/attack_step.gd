class_name AttackStep
extends Resource
## Одна стадия комбо: тайминги, урон, выпад, хитбокс и поза клинка.
## Поза задаётся в пространстве героя, смотрящего вправо: угол клинка 0 — вверх,
## плюс — назад (за спину), минус — вперёд; рукоять сдвигается от плеча по X (вперёд) и Y (вверх).

@export var display_name := ""
@export var duration := 0.36
@export var active_from := 0.07
@export var active_to := 0.18
## С какого момента можно продолжить комбо или уйти в перекат.
@export var chain_from := 0.15
@export var damage_multiplier := 1.0
@export var knockback := 4.5
@export var heavy := false
@export var lunge_speed := 2.5
@export var hitstop := 0.06
@export var hitbox_offset := Vector2(0.95, 1.0)
@export var hitbox_size := Vector2(1.5, 1.4)

@export_group("Поза клинка")
@export var blade_from := 0.9
@export var blade_to := -2.4
@export var grip_from := Vector2.ZERO
@export var grip_to := Vector2.ZERO
