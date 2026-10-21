class_name PlayerFoley
extends RefCounted
## Звуки тела героя: шаги в ритме бега и приземление.

## Сколько метров между шагами на бегу.
const STEP_DISTANCE := 1.55
## С какой скорости падения приземление слышно.
const LAND_SPEED := 4.0

var _stride := 0.0
var _was_on_floor := true
var _fall_speed := 0.0


## walking — герой идёт сам (не кувырок и не скольжение).
func update(on_floor: bool, velocity: Vector3, at: Vector3, delta: float, walking: bool) -> void:
	if not on_floor:
		# На кадре касания скорость уже погашена — помним скорость падения с прошлого кадра.
		_fall_speed = maxf(-velocity.y, 0.0)
	elif not _was_on_floor and _fall_speed > LAND_SPEED:
		Sfx.play(&"player_land", at)
		_stride = 0.0
	elif walking and absf(velocity.x) > 0.5:
		_stride += absf(velocity.x) * delta
		if _stride >= STEP_DISTANCE:
			_stride -= STEP_DISTANCE
			Sfx.play(&"player_step_floor", at)
	else:
		# Стоит — первый шаг прозвучит вскоре после старта.
		_stride = STEP_DISTANCE * 0.6
	_was_on_floor = on_floor
