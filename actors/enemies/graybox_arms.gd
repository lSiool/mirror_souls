class_name GrayboxArms
extends RefCounted
## Руки врага-гуманоида в graybox, до моделей (§3.3, 2026-11-09): две капсулы на плечевых шарнирах
## по бокам тела — ближняя к камере (front) и дальняя (back). Кисть тянется к цели: к оружию,
## к глазам в слепоте. До цели рука не дотягивается — укорачивается (не короче MIN_REACH).
##
## Всё в пространстве Visual врага: враг смотрит вправо (+X), разворот делает сам Visual.
## Рука висит вниз; угол шарнира — как у оружия героя: «+» — вперёд, «−» — назад.

const MIN_REACH := 0.55
## Длина руки — доля высоты плеча над полом, толщина — доля длины.
const LENGTH_SHARE := 0.42
const RADIUS_SHARE := 0.11

var front: Node3D
var back: Node3D
var length := 0.75


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
	arms.front = arms._arm(visual, "ArmFront", shoulder, radius, material)
	arms.back = arms._arm(visual, "ArmBack", Vector3(shoulder.x, shoulder.y, -shoulder.z), radius, material)
	return arms


func _arm(visual: Node3D, arm_name: String, shoulder: Vector3, radius: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = arm_name
	pivot.position = shoulder
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = length
	capsule.radial_segments = 8
	capsule.rings = 2
	var mesh := MeshInstance3D.new()
	mesh.name = "Arm"
	mesh.mesh = capsule
	mesh.material_override = material
	mesh.position = Vector3(0.0, -length * 0.5, 0.0)
	pivot.add_child(mesh)
	visual.add_child(pivot)
	pivot.rotation.z = 0.12
	return pivot


## Протянуть кисть к точке (пространство Visual) со скоростью rate.
func reach(arm: Node3D, target: Vector3, delta: float, rate := 12.0) -> void:
	var d := target - arm.position
	var angle := atan2(d.x, -d.y)
	var stretch := clampf(Vector2(d.x, d.y).length() / length, MIN_REACH, 1.0)
	var k := 1.0 - exp(-rate * delta)
	arm.rotation.z = lerp_angle(arm.rotation.z, angle, k)
	arm.scale.y = lerpf(arm.scale.y, stretch, k)


## Рука под углом angle и в полную длину.
func swing(arm: Node3D, angle: float, delta: float, rate := 10.0) -> void:
	var k := 1.0 - exp(-rate * delta)
	arm.rotation.z = lerp_angle(arm.rotation.z, angle, k)
	arm.scale.y = lerpf(arm.scale.y, 1.0, k)


## Где сейчас кисть (пространство Visual).
func hand(arm: Node3D) -> Vector3:
	var a := arm.rotation.z
	return arm.position + Vector3(sin(a), -cos(a), 0.0) * length * arm.scale.y
