class_name ArmRoom
extends SkeletonModifier3D
## Руки снаружи тела (2026-11-16): клипы сняты на тонком манекене, а у своей модели торс толще
## (оборотень — грудь и бока в разы шире), и кисти уходят в тело. Поверх клипа плечо отводит руку
## ровно настолько, чтобы локоть, запястье и кончики когтей легли на край торса, — с любым клипом.
##
## Торс — эллипс вокруг оси таз → шея: полуоси вбок и вперёд-назад в долях длины этой оси
## (не зависит от масштаба скелета). Точки ниже таза и выше шеи не трогает.

const SIDES := [&"Left", &"Right"]
## Ось торса продолжается вниз (бёдра, полы одежды) на эту долю.
const BELOW_HIPS := 0.3
## Длина кисти с когтями — доля предплечья.
const HAND_REACH := 0.6
## Отвод руки — не больше (рад).
const MAX_ANGLE := 0.9

## Полуоси торса: вбок и вперёд-назад, доли длины таз → шея.
var side_radius := 0.37
var depth_radius := 0.45

## Отвод в этом кадре (рад), левая и правая — для проверки (витрина персонажей).
var last_turn := Vector2.ZERO

var _bones := {}


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone: StringName in [&"Hips", &"Neck"]:
		_bones[bone] = skeleton.find_bone(bone)
	for side: StringName in SIDES:
		for part: String in ["UpperArm", "LowerArm", "Hand"]:
			_bones[side + part] = skeleton.find_bone(side + part)
	if _bones.values().has(-1):
		_bones.clear()


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _bones.is_empty():
		return
	var hips := skeleton.get_bone_global_pose(_bones[&"Hips"]).origin
	var neck := skeleton.get_bone_global_pose(_bones[&"Neck"]).origin
	var axis := neck - hips
	var length := axis.length()
	if length < 0.001:
		return
	axis /= length
	var shoulders := skeleton.get_bone_global_pose(_bones[&"LeftUpperArm"]).origin - skeleton.get_bone_global_pose(_bones[&"RightUpperArm"]).origin
	var side := (shoulders - axis * shoulders.dot(axis)).normalized()
	var depth := axis.cross(side)
	for s: StringName in SIDES:
		var upper: int = _bones[s + "UpperArm"]
		var pose := skeleton.get_bone_global_pose(upper)
		var elbow := skeleton.get_bone_global_pose(_bones[s + "LowerArm"]).origin
		var wrist := skeleton.get_bone_global_pose(_bones[s + "Hand"]).origin
		var tip := wrist + (wrist - elbow) * HAND_REACH
		var points: Array[Vector3] = [elbow, wrist.lerp(elbow, 0.5), wrist, tip]
		var outward := side if s == &"Left" else -side
		var turn := Quaternion.IDENTITY
		# Несколько шагов: отвели самую глубокую точку — пересчитали остальные.
		for step in 3:
			var worst := 0.0
			var from := Vector3.ZERO
			var to := Vector3.ZERO
			for p in points:
				var moved := pose.origin + turn * (p - pose.origin)
				var push := _push_out(moved - hips, axis, side, depth, outward, length)
				if push.length() > worst:
					worst = push.length()
					from = moved - pose.origin
					to = moved + push - pose.origin
			if worst < 0.002 or from.length() < 0.001:
				break
			turn = Quaternion(from.normalized(), to.normalized()) * turn
		last_turn[SIDES.find(s)] = minf(turn.get_angle(), MAX_ANGLE)
		if turn.get_angle() < 0.001:
			continue
		if turn.get_angle() > MAX_ANGLE:
			turn = Quaternion(turn.get_axis(), MAX_ANGLE)
		pose.basis = Basis(turn) * pose.basis
		skeleton.set_bone_global_pose(upper, pose)


## Насколько сдвинуть точку (от таза), чтобы она легла на край эллипса торса; снаружи — ноль.
func _push_out(r: Vector3, axis: Vector3, side: Vector3, depth: Vector3, outward: Vector3, length: float) -> Vector3:
	var along := r.dot(axis) / length
	if along < -BELOW_HIPS or along > 1.0:
		return Vector3.ZERO
	var flat := r - axis * r.dot(axis)
	var x := flat.dot(side) / (side_radius * length)
	var z := flat.dot(depth) / (depth_radius * length)
	var q := x * x + z * z
	if q >= 1.0:
		return Vector3.ZERO
	if q < 0.0001:
		return outward * side_radius * length
	return flat / sqrt(q) - flat
