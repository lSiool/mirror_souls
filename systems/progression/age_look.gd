class_name AgeLook
extends RefCounted
## Как возраст виден на капсуле (§8.6): рост, плечи, седина, сутулость. Заглушка до модели,
## где то же сделают blend shapes (§7.4). Одни числа и для героя, и для его отражения.

const HAIR_DARK := Color(0.16, 0.11, 0.08)
const HAIR_GREY := Color(0.78, 0.78, 0.76)
const STOOP_MAX := 0.16


## Масштаб капсулы: растёт до 24 лет, плечи раздаются до 40.
static func body_scale(age: float) -> Vector3:
	var height := lerpf(0.95, 1.03, clampf((age - 14.0) / 10.0, 0.0, 1.0))
	var width := lerpf(0.92, 1.12, clampf((age - 14.0) / 26.0, 0.0, 1.0))
	return Vector3(width, height, width)


## Седина 0…1: с 30 лет, к 50 — полностью.
static func hair_color(age: float) -> Color:
	return HAIR_DARK.lerp(HAIR_GREY, clampf((age - 30.0) / 20.0, 0.0, 1.0))


## Наклон вперёд, рад: сутулится после 38.
static func stoop(age: float) -> float:
	return STOOP_MAX * clampf((age - 38.0) / 14.0, 0.0, 1.0)
