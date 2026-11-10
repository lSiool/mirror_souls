class_name LadderLimbs
extends Node3D
## Лазание по лестнице на манекене (§3.3, 2026-11-10). В наборах UAL нет клипа лестницы, поэтому
## поза процедурная: герой разворачивается к лестнице, спиной к камере; кисти и стопы ведёт
## TwoBoneIK3D к перекладинам. Конечности переставляются по очереди — правая рука вместе с левой
## ногой, потом наоборот, — и только пока герой движется; стоит — держится за свои перекладины.
##
## Узел живёт внутри HeroModel; цели IK — его дети, в мире.

## Шаг перекладин и высота первой — как у Ladder.
const RUNG := 0.45
const FIRST_RUNG := 0.3
## Где перекладины относительно лестницы по глубине (Ladder рисует их на z = -0.45) — чуть ближе
## к герою, чтобы ладонь лежала на перекладине, а не в ней.
const RUNG_Z := -0.4
## Кисти — у стоек, стопы — ближе к середине (м от оси лестницы).
const HAND_X := 0.2
const FOOT_X := 0.13
## Над стопами: куда тянутся кисти и стопы (рост 1.0 — модель уже в масштабе героя).
const HAND_UP := 1.8
const FOOT_UP := 0.32
## Как быстро конечность переносится на новую перекладину (м/с) и насколько отходит от лестницы
## в переносе.
const SWAP_SPEED := 3.2
const SWAP_LIFT := 0.12

## Порядок настроек IK: правая кисть, левая кисть, правая стопа, левая стопа.
const LIMBS := [
	["RightUpperArm", "RightLowerArm", "RightHand"],
	["LeftUpperArm", "LeftLowerArm", "LeftHand"],
	["RightUpperLeg", "RightLowerLeg", "RightFoot"],
	["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"],
]

var _ik: TwoBoneIK3D
var _targets: Array[Node3D] = []
var _poles: Array[Node3D] = []
## Текущая высота каждой конечности (мир) — к ней тянется цель.
var _at: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _active := false


## Создать IK на скелете модели. Зовёт HeroModel один раз.
func rig(skeleton: Skeleton3D) -> void:
	_ik = TwoBoneIK3D.new()
	_ik.name = &"LadderIK"
	skeleton.add_child(_ik)
	_ik.set_setting_count(LIMBS.size())
	for i in LIMBS.size():
		_ik.set_root_bone_name(i, LIMBS[i][0])
		_ik.set_middle_bone_name(i, LIMBS[i][1])
		_ik.set_end_bone_name(i, LIMBS[i][2])
		var target := Node3D.new()
		target.name = "Target%d" % i
		add_child(target)
		target.top_level = true
		_targets.append(target)
		_ik.set_target_node(i, _ik.get_path_to(target))
		var pole := Node3D.new()
		pole.name = "Pole%d" % i
		add_child(pole)
		pole.top_level = true
		_poles.append(pole)
		_ik.set_pole_node(i, _ik.get_path_to(pole))
	_ik.influence = 0.0


## Каждый кадр, пока герой на лестнице.
func climb(ladder: Ladder, feet: Vector3, delta: float) -> void:
	if _ik == null:
		return
	var axis := ladder.global_position
	for i in LIMBS.size():
		var hand := i < 2
		var right := i % 2 == 0
		# Правая рука и левая нога — одна пара, вторая пара сдвинута на полшага перекладины.
		var shift := 0.0 if (right == hand) else RUNG * 0.5
		var want := feet.y + (HAND_UP if hand else FOOT_UP) + shift
		var rung := axis.y + FIRST_RUNG + roundf((want - axis.y - FIRST_RUNG) / RUNG) * RUNG
		rung = minf(rung, axis.y + ladder.height)
		if not _active:
			_at[i] = rung
		var gap := rung - _at[i]
		_at[i] = move_toward(_at[i], rung, SWAP_SPEED * delta)
		var lift := SWAP_LIFT * clampf(absf(gap) / (RUNG * 0.5), 0.0, 1.0)
		var side := (HAND_X if hand else FOOT_X) * (1.0 if right else -1.0)
		_targets[i].global_position = Vector3(axis.x + side, _at[i], axis.z + RUNG_Z + lift)
		# Локти — в стороны и к камере, колени — вперёд к лестнице и чуть наружу.
		if hand:
			_poles[i].global_position = Vector3(axis.x + side * 3.0, _at[i] - 0.5, axis.z + 0.4)
		else:
			_poles[i].global_position = Vector3(axis.x + side * 2.0, _at[i] + 0.6, axis.z - 1.0)
	_active = true
	_ik.influence = 1.0


## Герой сошёл с лестницы: IK отпускает конечности.
func release() -> void:
	_active = false
	if _ik:
		_ik.influence = 0.0
