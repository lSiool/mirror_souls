class_name GripHands
extends SkeletonModifier3D
## Кулак на рукояти (§3.3, §6.3, 2026-11-09): после IK рук поворачивает кисть так, чтобы рукоять
## шла поперёк ладони — вдоль линии костяшек (от указательного к мизинцу), и сжимает пальцы.
## Так оружие лежит в руке анатомически, а не торчит из запястья. Стоит после TwoBoneIK3D.
##
## Оси кисти манекена (SkeletonProfileHumanoid): пальцы — +Y, костяшки — X, ладонь смотрит в +Z;
## пальцы сгибаются поворотом вокруг X в сторону ладони.

## Точка в ладони, через которую идёт рукоять (в пространстве кости кисти, до масштаба модели).
const PALM := Vector3(0.0, 0.085, 0.035)
## Сгиб суставов пальцев в кулаке: основная, средняя, ногтевая фаланга.
const CURL := [1.35, 1.55, 1.0]
const FINGERS := ["Index", "Middle", "Ring", "Little"]
const PHALANGES := ["Proximal", "Intermediate", "Distal"]

## Что держит кисть (0 — правая, 1 — левая): ось рукояти в мире; нулевая — кисть свободна.
var axes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]

var _hands: Array[int] = []
var _fingers: Array = [[], []]


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for side: String in ["Right", "Left"]:
		_hands.append(skeleton.find_bone(side + "Hand"))
		var bones := []
		for finger: String in FINGERS:
			for joint in PHALANGES.size():
				bones.append([skeleton.find_bone(side + finger + PHALANGES[joint]), joint])
		_fingers[_hands.size() - 1] = bones


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _hands.size() < 2:
		return
	for side in 2:
		var axis := axes[side]
		if axis == Vector3.ZERO:
			continue
		var hand := _hands[side]
		var pose := skeleton.get_bone_global_pose(hand)
		# Ось рукояти — в пространство скелета; знак — ближайший к нынешней линии костяшек.
		var want := (skeleton.global_basis.inverse() * axis).normalized()
		var knuckles := (pose.basis * Vector3.RIGHT).normalized()
		if knuckles.dot(want) < 0.0:
			want = -want
		var turn := Quaternion(knuckles, want)
		skeleton.set_bone_global_pose(hand, Transform3D(Basis(turn) * pose.basis, pose.origin))
		for entry: Array in _fingers[side]:
			var bone: int = entry[0]
			if bone < 0:
				continue
			var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(bone, rest * Quaternion(Vector3.RIGHT, CURL[entry[1]]))


## Точка ладони кисти side (0 — правая) в мире — по итоговой позе (вызывать после обновления скелета).
func palm(side: int) -> Vector3:
	var skeleton := get_skeleton()
	return skeleton.global_transform * (skeleton.get_bone_global_pose(_hands[side]) * PALM)
