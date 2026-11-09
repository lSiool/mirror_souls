class_name SmithBody
extends SkeletonModifier3D
## Тело Кузнеца под тяжёлым молотом (§6.3, 2026-11-09). Клипов двуручного молота в наборах нет,
## поэтому стойку, прогиб и разворот корпуса он строит сам поверх клипа — до IK рук. Числа задаёт
## EnemyModel по углу молота: замах над головой — прогиб назад, удар в пол — присед и складка
## вперёд, заведённый назад молот — правое плечо уходит назад, пронёсся вперёд — выходит вперёд.
##
## Ноги — широкая стойка, левая впереди: таз опущен, стопы стоят на земле. Бедро и голень
## решаются к точке стопы аналитически (колено — вперёд и чуть наружу), стопа плоская.
## На ходу ноги отдаются клипу шага (legs = 0), корпус остаётся согнутым под молотом.

const SPINE := [&"Spine", &"Chest", &"UpperChest"]
## Доля разворота, которую берёт таз (с ногами в стойке): плечи не крутятся одни.
const HIPS_TWIST := 0.3
## Стопы в стойке, пространство модели (x — вперёд, z — вправо, рост 1.0): точка лодыжки,
## поворот носка (плюс — влево), куда смотрит колено.
const FEET := {
	&"Left": [Vector3(0.2, 0.1, -0.14), 0.15, Vector3(1.0, 0.0, -0.3)],
	&"Right": [Vector3(-0.22, 0.1, 0.15), -0.45, Vector3(1.0, 0.0, 0.45)],
}
## Голова доворачивает обратно на долю наклона и разворота — взгляд на герое.
const HEAD_KEEP := 0.6

## Пространство модели (узел Lean у EnemyModel).
var model_space: Node3D
## Наклон корпуса вперёд (рад; минус — прогиб назад), разворот плеч (плюс — правое плечо назад).
var bend := 0.0
var twist := 0.0
## Присед — на сколько опущен таз, и на сколько он ушёл назад (рост 1.0); ширина шага — доля стойки.
var crouch := 0.0
var hips_back := 0.0
var stride := 1.0
## Голова поднята сверх позы (рад) — когда клип шага её опускает.
var head_up := 0.0
## Насколько поза корпуса и ног лежит поверх клипа (0 — чистый клип).
var body := 0.0
var legs := 0.0

var _bones := {}


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone: StringName in [&"Hips", &"Head"] + SPINE:
		_bones[bone] = skeleton.find_bone(bone)
	for side: StringName in FEET:
		for part: String in ["UpperLeg", "LowerLeg", "Foot"]:
			_bones[side + part] = skeleton.find_bone(side + part)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or model_space == null or _bones.is_empty():
		return
	if body <= 0.001 and legs <= 0.001:
		return
	var to_skeleton := skeleton.global_transform.affine_inverse() * model_space.global_transform
	var up := (to_skeleton.basis * Vector3.UP).normalized()
	var lateral := (to_skeleton.basis * Vector3.BACK).normalized()
	# Таз ниже и назад — только вместе со стойкой ног, иначе шаг клипа уйдёт в пол.
	var hips_turn := twist * HIPS_TWIST * legs * body
	if legs > 0.001:
		# Таз опускается, уходит назад и берёт долю разворота — ноги потом встанут на свои места.
		var hips: int = _bones[&"Hips"]
		var pose := skeleton.get_bone_global_pose(hips)
		pose.origin += to_skeleton.basis * Vector3(-hips_back, -crouch, 0.0) * legs
		pose.basis = Basis(Quaternion(up, -hips_turn)) * pose.basis.orthonormalized()
		skeleton.set_bone_global_pose(hips, pose)
	if body > 0.001:
		# Наклон и остаток разворота — поровну на три позвонка; голова доворачивает обратно.
		var share := body / SPINE.size()
		var turn := Quaternion(up, -(twist * body - hips_turn) / SPINE.size()) * Quaternion(lateral, -bend * share)
		for bone: StringName in SPINE:
			_rotate(skeleton, _bones[bone], turn)
		_rotate(skeleton, _bones[&"Head"], Quaternion(up, twist * body * HEAD_KEEP) * Quaternion(lateral, (bend * HEAD_KEEP + head_up) * body))
	if legs > 0.001:
		for side: StringName in FEET:
			_leg(skeleton, side, to_skeleton, up)


## Повернуть кость вокруг её начала (пространство скелета) — дети идут следом.
func _rotate(skeleton: Skeleton3D, bone: int, turn: Quaternion) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	skeleton.set_bone_global_pose(bone, Transform3D(Basis(turn) * pose.basis.orthonormalized(), pose.origin))


## Нога к точке стопы: колено в плоскости «бедро — стопа — полюс», голень на стопу, стопа плоская.
## Итог смешивается с позой клипа по legs.
func _leg(skeleton: Skeleton3D, side: StringName, to_skeleton: Transform3D, up: Vector3) -> void:
	var upper: int = _bones[side + "UpperLeg"]
	var lower: int = _bones[side + "LowerLeg"]
	var foot: int = _bones[side + "Foot"]
	var stance: Array = FEET[side]
	var spot: Vector3 = stance[0]
	var target := to_skeleton * Vector3(spot.x * stride, spot.y, spot.z)
	var pole := (to_skeleton.basis * (stance[2] as Vector3)).normalized()
	var hip := skeleton.get_bone_global_pose(upper)
	var knee := skeleton.get_bone_global_pose(lower)
	var ankle := skeleton.get_bone_global_pose(foot)
	var thigh := hip.origin.distance_to(knee.origin)
	var shin := knee.origin.distance_to(ankle.origin)
	var reach := target - hip.origin
	var distance := clampf(reach.length(), absf(thigh - shin) + 0.001, (thigh + shin) * 0.999)
	var along := reach.normalized()
	var cos_hip := (thigh * thigh + distance * distance - shin * shin) / (2.0 * thigh * distance)
	var out := (pole - along * pole.dot(along)).normalized()
	var knee_at := hip.origin + along * thigh * cos_hip + out * thigh * sqrt(maxf(0.0, 1.0 - cos_hip * cos_hip))
	var swing := Quaternion((knee.origin - hip.origin).normalized(), (knee_at - hip.origin).normalized())
	_blend(skeleton, upper, Basis(swing) * hip.basis.orthonormalized())
	knee = skeleton.get_bone_global_pose(lower)
	ankle = skeleton.get_bone_global_pose(foot)
	swing = Quaternion((ankle.origin - knee.origin).normalized(), (target - knee.origin).normalized())
	_blend(skeleton, lower, Basis(swing) * knee.basis.orthonormalized())
	var flat := Basis(Quaternion(up, stance[1])) * skeleton.get_bone_global_rest(foot).basis.orthonormalized()
	_blend(skeleton, foot, flat)


func _blend(skeleton: Skeleton3D, bone: int, want: Basis) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var basis := pose.basis.orthonormalized().slerp(want, legs) if legs < 0.999 else want
	skeleton.set_bone_global_pose(bone, Transform3D(basis, pose.origin))
