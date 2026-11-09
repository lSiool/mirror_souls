class_name GripHands
extends SkeletonModifier3D
## Кулак на рукояти (§3.3, §6.3, 2026-11-09): после IK рук поворачивает кисть так, чтобы рукоять
## шла поперёк ладони — вдоль линии костяшек (от указательного к мизинцу), и сжимает пальцы.
## Так оружие лежит в руке анатомически, а не торчит из запястья. Стоит после TwoBoneIK3D.
##
## Оси кисти манекена (SkeletonProfileHumanoid): пальцы — +Y, костяшки — X, ладонь смотрит в +Z;
## пальцы сгибаются поворотом вокруг X в сторону ладони. +X правой кисти смотрит от мизинца
## к указательному, у левой — наоборот (кисти зеркальны).
##
## Хват — как держат молот, а не нож обратным хватом: оружие выходит из кулака со стороны большого
## пальца, рукоять — из-под мизинца. Разворот кулака делят предплечье (вокруг своей оси, как
## пронация) и кисть — запястье не скручивается.
##
## Двуручное (follow_gap): левая ладонь ложится на рукоять точно на follow_gap выше правой — по уже
## повёрнутому кулаку видно, где должно быть запястье, и левая рука (плечо, предплечье) решается
## к нему заново; локоть остаётся в той же плоскости, что дал IK.

## Точка в ладони, через которую идёт рукоять (в пространстве кости кисти, до масштаба модели).
const PALM := Vector3(0.0, 0.085, 0.035)
## Сгиб суставов пальцев в кулаке: основная, средняя, ногтевая фаланга.
const CURL := [1.35, 1.55, 1.0]
const FINGERS := ["Index", "Middle", "Ring", "Little"]
## Какую долю разворота кулака вокруг оси предплечья берёт само предплечье.
const FOREARM_SHARE := 0.6
const PHALANGES := ["Proximal", "Intermediate", "Distal"]

## Что держит кисть (0 — правая, 1 — левая): ось рукояти в мире; нулевая — кисть свободна.
var axes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Левая ладонь — на рукояти на столько (м, в мире) дальше правой к оружию; 0 — левая сама по себе.
var follow_gap := 0.0

var _hands: Array[int] = []
var _forearms: Array[int] = []
var _uppers: Array[int] = []
var _fingers: Array = [[], []]


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for side: String in ["Right", "Left"]:
		_hands.append(skeleton.find_bone(side + "Hand"))
		_forearms.append(skeleton.find_bone(side + "LowerArm"))
		_uppers.append(skeleton.find_bone(side + "UpperArm"))
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
		# Ось рукояти (к оружию) — в пространство скелета; +X кисти — к оружию у правой, от него у левой.
		var want := (skeleton.global_basis.inverse() * axis).normalized() * (1.0 if side == 0 else -1.0)
		var forearm := _forearms[side]
		var arm_pose := skeleton.get_bone_global_pose(forearm)
		var pose := skeleton.get_bone_global_pose(hand)
		var roll_axis := (pose.origin - arm_pose.origin).normalized()
		var knuckles := (pose.basis * Vector3.RIGHT).normalized()
		var have := knuckles - roll_axis * knuckles.dot(roll_axis)
		var need := want - roll_axis * want.dot(roll_axis)
		if have.length() > 0.01 and need.length() > 0.01:
			# Долю разворота — предплечьем вокруг своей оси: кисть остаётся на месте.
			var roll := have.normalized().signed_angle_to(need.normalized(), roll_axis) * FOREARM_SHARE
			skeleton.set_bone_global_pose(forearm, Transform3D(Basis(Quaternion(roll_axis, roll)) * arm_pose.basis.orthonormalized(), arm_pose.origin))
			pose = skeleton.get_bone_global_pose(hand)
			knuckles = (pose.basis * Vector3.RIGHT).normalized()
		var turn := Quaternion(knuckles, want)
		skeleton.set_bone_global_pose(hand, Transform3D(Basis(turn) * pose.basis.orthonormalized(), pose.origin))
		for entry: Array in _fingers[side]:
			var bone: int = entry[0]
			if bone < 0:
				continue
			var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(bone, rest * Quaternion(Vector3.RIGHT, CURL[entry[1]]))
	if follow_gap > 0.0 and axes[0] != Vector3.ZERO and axes[1] != Vector3.ZERO:
		_follow(skeleton)


## Левая ладонь — на рукоять выше правой: запястье туда, где ладонь повёрнутого кулака ляжет точно.
func _follow(skeleton: Skeleton3D) -> void:
	var to_skeleton := skeleton.global_basis.inverse()
	var along := to_skeleton * axes[0].normalized()
	var right := skeleton.get_bone_global_pose(_hands[0]) * PALM
	var hand := skeleton.get_bone_global_pose(_hands[1])
	var basis := hand.basis.orthonormalized()
	var wrist := right + along * follow_gap - basis * PALM
	reach(skeleton, _uppers[1], _forearms[1], _hands[1], wrist)
	var moved := skeleton.get_bone_global_pose(_hands[1])
	skeleton.set_bone_global_pose(_hands[1], Transform3D(basis, moved.origin))


## Две кости (плечо — локоть — кисть) к точке target (пространство скелета): локоть остаётся в той
## плоскости, где был; недостижимое — рука вытянута в ту сторону.
static func reach(skeleton: Skeleton3D, upper: int, lower: int, end: int, target: Vector3) -> void:
	var root := skeleton.get_bone_global_pose(upper)
	var middle := skeleton.get_bone_global_pose(lower)
	var tip := skeleton.get_bone_global_pose(end)
	var first := root.origin.distance_to(middle.origin)
	var second := middle.origin.distance_to(tip.origin)
	var line := target - root.origin
	var distance := clampf(line.length(), absf(first - second) + 0.001, (first + second) * 0.999)
	var along := line.normalized()
	var bend := middle.origin - root.origin
	var out := bend - along * bend.dot(along)
	if out.length() < 0.0001:
		out = along.cross(Vector3.UP)
	out = out.normalized()
	var cos_root := (first * first + distance * distance - second * second) / (2.0 * first * distance)
	var elbow := root.origin + along * first * cos_root + out * first * sqrt(maxf(0.0, 1.0 - cos_root * cos_root))
	var swing := Quaternion(bend.normalized(), (elbow - root.origin).normalized())
	skeleton.set_bone_global_pose(upper, Transform3D(Basis(swing) * root.basis.orthonormalized(), root.origin))
	middle = skeleton.get_bone_global_pose(lower)
	tip = skeleton.get_bone_global_pose(end)
	swing = Quaternion((tip.origin - middle.origin).normalized(), (target - middle.origin).normalized())
	skeleton.set_bone_global_pose(lower, Transform3D(Basis(swing) * middle.basis.orthonormalized(), middle.origin))


## Точка ладони кисти side (0 — правая) в мире — по итоговой позе (вызывать после обновления скелета).
func palm(side: int) -> Vector3:
	var skeleton := get_skeleton()
	return skeleton.global_transform * (skeleton.get_bone_global_pose(_hands[side]) * PALM)
