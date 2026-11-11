class_name LadderLimbs
extends Node3D
## Лазание по лестнице на манекене (§3.3). В наборах UAL нет клипа лестницы, поэтому поза
## процедурная: герой разворачивается к лестнице, спиной к камере; кисти и стопы ведёт
## TwoBoneIK3D.
##
## Вверх — перехват по перекладинам (2026-11-11, по видео автора): шаг привязан к высоте героя,
## а не ко времени, поэтому конечности не отстают от тела на любой скорости. Правая рука идёт
## вместе с левой ногой, левая рука — с правой ногой; пара стоит на своей перекладине, пока тело
## проходит одну, и за вторую переносится на две выше. Стоит — держится как остановился.
## Вниз — съезжает: ладони и стопы на стойках, колени разведены (как съезжают по лестнице в Souls).
##
## Это заглушка до настоящего клипа: он ляжет на тот же скелет, и этот узел уйдёт.

## Шаг перекладин и высота первой — как у Ladder.
const RUNG := 0.45
const FIRST_RUNG := 0.3
## Где перекладины относительно лестницы по глубине (Ladder рисует их на z = -0.45) — чуть ближе
## к герою, чтобы ладонь лежала на перекладине, а не в ней.
const RUNG_Z := -0.4
## Кисти — на стойках (перехват идёт по ним), стопы — на перекладинах, ближе к середине (м от оси).
const HAND_X := 0.3
const FOOT_X := 0.13
## На сколько перекладин выше ног стоит конечность, когда её пара только что перехватилась.
const HAND_RUNGS := 4.5
## Выше этого над ногами рука не дотягивается: перекладину берёт вытянутой рукой.
const REACH := 2.0
const FOOT_RUNGS := 0.0
## Насколько конечность отходит от лестницы в переносе.
const SWAP_LIFT := 0.12
## Съезд вниз: кисти и стопы на стойках (м от оси), на такой высоте над ногами героя.
const SLIDE_X := 0.31
const SLIDE_HAND_UP := 1.8
const SLIDE_FOOT_UP := -0.1
## Быстрее этого вниз — съезжает (м/с).
const SLIDE_FROM := 0.3
## Как быстро поза перетекает между перехватом и съездом (1/с).
const BLEND := 12.0

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
## Где каждая конечность относительно ног героя и оси лестницы — сглаженно.
var _rel: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
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


## Каждый кадр, пока герой на лестнице. speed_y — его скорость по вертикали.
func climb(ladder: Ladder, feet: Vector3, speed_y: float, delta: float) -> void:
	if _ik == null:
		return
	var axis := ladder.global_position
	var sliding := speed_y < -SLIDE_FROM
	# Высота ног в перекладинах от первой; цикл перехвата — две перекладины.
	var rungs := (feet.y - axis.y - FIRST_RUNG) / RUNG
	var cycle := rungs * 0.5
	var k := 1.0 - exp(-BLEND * delta) if _active else 1.0
	for i in LIMBS.size():
		var hand := i < 2
		var right := i % 2 == 0
		var side := 1.0 if right else -1.0
		var want: Vector3
		if sliding:
			want = Vector3(side * SLIDE_X, SLIDE_HAND_UP if hand else SLIDE_FOOT_UP, RUNG_Z + 0.06)
		else:
			# Пара «правая рука + левая нога» держит чётные перекладины, вторая пара — нечётные.
			var first_pair := right == hand
			var at := cycle if first_pair else cycle + 0.5
			var planted := 2.0 * floorf(at) - (0.0 if first_pair else 1.0)
			var swing := clampf((at - floorf(at) - 0.5) * 2.0, 0.0, 1.0)
			var rung := planted + 2.0 * smoothstep(0.0, 1.0, swing) + (HAND_RUNGS if hand else FOOT_RUNGS)
			var y := minf(minf((rung - rungs) * RUNG, REACH), axis.y + ladder.height - feet.y) if hand else (rung - rungs) * RUNG
			want = Vector3(side * (HAND_X if hand else FOOT_X), y, RUNG_Z + SWAP_LIFT * sin(swing * PI))
		_rel[i] = _rel[i].lerp(want, k)
		var at_world := Vector3(axis.x + _rel[i].x, feet.y + _rel[i].y, axis.z + _rel[i].z)
		_targets[i].global_position = at_world
		# Локти — в стороны и к камере, колени — к лестнице и немного наружу: ноги не складываются
		# сквозь тело и не торчат в стороны.
		if hand:
			_poles[i].global_position = Vector3(axis.x + side * 0.7, at_world.y - 0.7, axis.z + 0.6)
		else:
			_poles[i].global_position = Vector3(axis.x + side * 0.4, feet.y + 0.6, axis.z - 1.2)
	_active = true
	_ik.influence = 1.0


## Герой сошёл с лестницы: IK отпускает конечности.
func release() -> void:
	_active = false
	if _ik:
		_ik.influence = 0.0
