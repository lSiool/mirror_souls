class_name GrayboxArms
extends RefCounted
## Руки врага-гуманоида в graybox, до моделей (§3.3, 2026-11-09): плечо и предплечье на локте,
## по бокам тела — правая (+Z в пространстве Visual, враг смотрит вправо) и левая (−Z).
## Кисть ведёт двухзвенная IK в плоскости кадра (X/Y): локоть сгибается вниз и вперёд.
##
## Правило (2026-11-09): оружие всегда в руке. Если хват дальше, чем дотягивается рука, кисть
## встаёт на край досягаемости, а оружие подтягивается к ней (Dummy._update_arms) — хитбокс
## удара от этого не меняется, он отдельный.
##
## Углы — как у оружия героя: 0 — рука висит вниз, «+» — вперёд, «−» — назад.

## Длина руки (плечо + предплечье) — доля высоты плеча над полом, толщина — доля длины.
const LENGTH_SHARE := 0.5
const RADIUS_SHARE := 0.1
## Ближе этого кисть к плечу не подходит (рука сложена).
const MIN_REACH := 0.2

var right: Node3D
var left: Node3D
var length := 0.9

## Куда тянется кисть сейчас (сглаженная цель) — по руке.
var _aim := {}
var _elbows := {}


## Руки по размеру тела: плечи — у верха Body, по бокам, чуть шире тела. Материал — тела врага,
## чтобы руки наливались красным в замахе и вспыхивали от удара вместе с ним.
static func build(visual: Node3D, body: MeshInstance3D, material: Material) -> GrayboxArms:
	var arms := GrayboxArms.new()
	var size := Vector3(0.6, 1.2, 0.45)
	if body.mesh is BoxMesh:
		size = (body.mesh as BoxMesh).size
	var top := body.position.y + size.y * 0.5
	arms.length = top * LENGTH_SHARE
	var radius := arms.length * RADIUS_SHARE
	var shoulder := Vector3(body.position.x, top - radius * 1.2, size.z * 0.5 + radius)
	arms.right = arms._arm(visual, "ArmRight", shoulder, radius, material)
	arms.left = arms._arm(visual, "ArmLeft", Vector3(shoulder.x, shoulder.y, -shoulder.z), radius, material)
	return arms


func _arm(visual: Node3D, arm_name: String, shoulder: Vector3, radius: float, material: Material) -> Node3D:
	var half := length * 0.5
	var pivot := Node3D.new()
	pivot.name = arm_name
	pivot.position = shoulder
	visual.add_child(pivot)
	pivot.add_child(_segment("Upper", half, radius, material))
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0.0, -half, 0.0)
	pivot.add_child(elbow)
	elbow.add_child(_segment("Fore", half, radius * 0.9, material))
	_elbows[pivot] = elbow
	_aim[pivot] = shoulder + Vector3(0.1, -length * 0.95, 0.0)
	_solve(pivot)
	return pivot


func _segment(segment_name: String, segment_length: float, radius: float, material: Material) -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = segment_length + radius
	capsule.radial_segments = 8
	capsule.rings = 2
	var mesh := MeshInstance3D.new()
	mesh.name = segment_name
	mesh.mesh = capsule
	mesh.material_override = material
	mesh.position = Vector3(0.0, -segment_length * 0.5, 0.0)
	return mesh


## Рука того же бока, что и точка (оружие справа — правая рука).
func arm_at(point: Vector3) -> Node3D:
	return right if point.z >= 0.0 else left


func other(arm: Node3D) -> Node3D:
	return left if arm == right else right


## Протянуть кисть к точке (пространство Visual) плавно, со скоростью rate.
func reach(arm: Node3D, target: Vector3, delta: float, rate := 12.0) -> void:
	var aim: Vector3 = _aim[arm]
	_aim[arm] = aim.lerp(target, 1.0 - exp(-rate * delta))
	_solve(arm)


## Кисть сразу в точку (хват оружия: рука не отстаёт от рукояти).
func hold(arm: Node3D, target: Vector3) -> void:
	_aim[arm] = target
	_solve(arm)


## Рука под углом angle почти в полную длину — плавно.
func swing(arm: Node3D, angle: float, delta: float, rate := 10.0) -> void:
	reach(arm, arm.position + Vector3(sin(angle), -cos(angle), 0.0) * length * 0.95, delta, rate)


## Где сейчас кисть (пространство Visual).
func hand(arm: Node3D) -> Vector3:
	var half := length * 0.5
	var shoulder := arm.rotation.z
	var fore := shoulder + (_elbows[arm] as Node3D).rotation.z
	return arm.position + (_dir(shoulder) + _dir(fore)) * half


## Куда смотрит предплечье (от локтя к кисти) — вдоль него ложится одноручное оружие.
func forearm(arm: Node3D) -> Vector3:
	return _dir(arm.rotation.z + (_elbows[arm] as Node3D).rotation.z)


## Двухзвенная IK: плечо и предплечье по половине длины, локоть вниз и вперёд.
func _solve(arm: Node3D) -> void:
	var half := length * 0.5
	var d: Vector3 = _aim[arm] - arm.position
	var distance := clampf(Vector2(d.x, d.y).length(), length * MIN_REACH, length * 0.999)
	var toward := atan2(d.x, -d.y)
	# Угол между плечом и направлением на цель и сгиб локтя — по теореме косинусов.
	var open := acos(clampf(distance / (2.0 * half), -1.0, 1.0))
	arm.rotation.z = toward - open
	(_elbows[arm] as Node3D).rotation.z = open * 2.0


static func _dir(angle: float) -> Vector3:
	return Vector3(sin(angle), -cos(angle), 0.0)
