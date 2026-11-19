class_name RyeField
extends Node3D
## Рожь по грудь (§8.13, Поля): густые колосья вдоль плоскости героя, волны ветра бегут по полю.
## Полоса от depth_from до depth_to по глубине мира Z: сзади рожь выше, спереди — ниже (не закрывать героя целиком),
## в самой плоскости героя — примятая тропа. Колосья — один MultiMesh, раскладка от seed (воспроизводима).
## Узел стоит серединой полосы на земле; rise — на сколько земля поднимается от левого края к правому (склон).
## Группа rye_field — для Полудницы: в ржи она прячется (Poludnitsa), и где она идёт, рожь клонится против ветра (disturb).

const SHADER := preload("res://world/common/rye_wind.gdshader")
## Глубина примятой тропы, где ходит герой: колосьев там мало.
const TRAIL := 0.45

@export var length := 12.0
@export var depth_from := -2.4
@export var depth_to := 1.5
@export var height := 1.3
@export var rise := 0.0
## Колосьев на квадратный метр.
@export var density := 14.0
@export var seed := 1
@export var color := Color(0.3, 0.24, 0.12)

var _material: ShaderMaterial


func _ready() -> void:
	add_to_group(&"rye_field")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.045
	stalk.bottom_radius = 0.012
	stalk.height = 1.0
	stalk.radial_segments = 3
	stalk.rings = 2
	var material := ShaderMaterial.new()
	material.shader = SHADER
	stalk.material = material
	_material = material
	var count := int(length * (depth_to - depth_from) * density)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = stalk
	multimesh.instance_count = count
	var placed := 0
	for i in count:
		var z := rng.randf_range(depth_from, depth_to)
		# На тропе — редкие колосья: герой их примял.
		if absf(z) < TRAIL and rng.randf() > 0.12:
			continue
		var x := rng.randf_range(-length * 0.5, length * 0.5)
		var h := height * rng.randf_range(0.75, 1.1) * (0.72 if z > TRAIL else 1.0)
		var tilt := rng.randf_range(-0.12, 0.12)
		var basis := Basis(Vector3.FORWARD, tilt).scaled(Vector3(1.0, h, 1.0))
		var y := rise * (x / length + 0.5) + h * 0.5 - 0.05
		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(x, y, z)))
		multimesh.set_instance_color(placed, color * rng.randf_range(0.7, 1.15))
		placed += 1
	multimesh.visible_instance_count = placed
	var field := MultiMeshInstance3D.new()
	field.multimesh = multimesh
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)


## Кто-то идёт под колосьями в точке at: полоса ржи клонится против ветра и дрожит; strength 0 — тихо.
func disturb(at: Vector3, strength: float) -> void:
	_material.set_shader_parameter(&"disturb", Vector4(at.x, at.z, strength, 1.5))


## Внутри ли полосы ржи точка на земле (по x и по высоте земли).
func covers(point: Vector3) -> bool:
	var local := to_local(point)
	if absf(local.x) > length * 0.5:
		return false
	var ground := rise * (local.x / length + 0.5)
	return absf(local.y - ground) < 1.5
