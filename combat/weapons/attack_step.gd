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
## Урон по стойкости врага: при нуле враг сбивается (стаггер).
@export var poise_damage := 15.0
@export var knockback := 4.5
@export var heavy := false
## Неуязвимость на весь удар (добивание, удар в спину).
@export var invulnerable := false
@export var lunge_speed := 2.5
@export var hitstop := 0.06
@export var hitbox_offset := Vector2(0.95, 1.0)
@export var hitbox_size := Vector2(1.5, 1.4)
## Звук попадания этой стадии (событие Sfx). Последний удар серии звучит по-своему — завершённо.
@export var hit_sound: StringName = &"sword_hit"
## Свист взмаха этой стадии: режущие — sword_swing, колющий выпад — свой.
@export var swing_sound: StringName = &"sword_swing"

@export_group("Поза клинка")
@export var blade_from := 0.9
@export var blade_to := -2.4
@export var grip_from := Vector2.ZERO
@export var grip_to := Vector2.ZERO
## Поворот клинка вокруг вертикали: 0 — в плоскости боя; -PI → 0 — горизонтальный мах
## из-за спины вперёд через сторону к камере.
@export var blade_yaw_from := 0.0
@export var blade_yaw_to := 0.0

@export_group("Критический удар")
## Добивание и удар в спину идут в три фазы (по ориентиру DS2): клинок входит
## (active_from–active_to) → враг висит на клинке → в release_at клинок выдёргивают,
## врага сбрасывают. 0 — без удержания: урон сразу в момент удара.
@export var release_at := 0.0
## Поза клинка к концу удержания (враг приподнят на клинке).
@export var blade_hold := -1.5708
@export var grip_hold := Vector2.ZERO
## Поза после рывка: клинок выдернут.
@export var blade_release := 0.5
@export var grip_release := Vector2.ZERO
## Насколько враг приподнимается на клинке, м.
@export var victim_lift := 0.0
## Скорость, с которой врага сбрасывают с клинка: X — от героя, Y — вверх.
@export var victim_throw := Vector2.ZERO
