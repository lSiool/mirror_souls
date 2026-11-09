class_name EnemyModel
extends Node3D
## Враг на манекене героя (§3.3, 2026-11-09): тот же гуманоид и те же клипы Quaternius, что у героя
## (HeroModel), — другой цвет и свои черты на костях. Пока так выглядят солдат и вампир.
## Модель только показывает: столкновения, хитбоксы и тайминги — у Dummy.
##
## Облик (look): солдат — шлем и меч в правой руке; вампир — бледный, плащ, высокий воротник,
## красные глаза, без оружия (когти). Тело красится материалом врага (Dummy._material) — оно
## наливается красным в замахе и вспыхивает от удара, как примитив.
##
## Слепота (§6.2): отшатнулся (Hit_Head), дальше обе кисти у глаз — их ведёт TwoBoneIK3D поверх
## клипа; меч ложится вдоль кисти и предплечья. Вампир шатается (Idle_Shield_Break).
##
## Кузнец — проклятый человек в 1.6 раза выше, движется медленнее. Своих клипов молота нет:
## угол молота ведёт Blacksmith, кисти по IK идут к хвату — от груди в сторону молота, не ниже,
## чем позволяет пол под навершием; GripHands разворачивает кулак поперёк рукояти, и молот ложится
## в ладонь правой кисти по итоговой позе скелета — оружие всегда в руке. Молот опущен — держит
## одной рукой, поднят — двумя. Сцены (сидит на камне, на колене) — клипами по Dummy._model_pose().
##
## Вампир перед превращением в мышь (Vampire): глаза разгораются (eyes_flare), руки раскинуты, плащ
## раскрыт крыльями (spread) — перепонка от кисти до колена, строится по костям после IK.

const SOLDIER := &"soldier"
const VAMPIRE := &"vampire"
const BLACKSMITH := &"blacksmith"
## Рост облика и темп клипов: крупный — медленнее.
const SIZE := {BLACKSMITH: 1.6}
const TEMPO := {BLACKSMITH: 0.75}
## Манекен (рост 1.0): высота плеча и груди, сколько от запястья до середины ладони.
const SHOULDER_Y := 1.41
const CHEST_Y := 1.27
const SHOULDER_Z := 0.19
const PALM_FROM_WRIST := 0.09
## Хват оружия — на таком расстоянии от груди в сторону молота (рост 1.0).
const GRIP_RADIUS := 0.38
## Сидит на камне (Dummy._seat_height): таз над сиденьем на столько (рост 1.0).
const SEAT_PELVIS := 0.12
## Из сцены (сидел, стоял на колене) в обычную позу — плавно, как встаёт.
const SCENE_BLEND := 0.8
## Кадр клипа Fixing_Kneeling, где стоит на колене, и переход в него.
const KNEEL_AT := 1.0
const KNEEL_BLEND := 0.3
## Клип удара по облику и доля клипа, где удар попадает (конец замаха).
const ATTACKS := {SOLDIER: [&"Sword_Regular_A", 0.42], VAMPIRE: [&"Melee_Hook", 0.45]}
const JOG_SPEED := 4.0
const WALK_SPEED := 1.6
## Кисти у глаз: от точки между глаз — вперёд и чуть вниз (запястье, ладонь закрывает глаза).
const PALM_AHEAD := 0.13
const PALM_DROP := 0.1
const PALM_SPREAD := 0.07

var look := SOLDIER
var hero: HeroModel
## Наклон всей фигуры поверх клипа: вздрог, стойка шатающегося.
var lean: Node3D
var _enemy: Dummy
var _ik: TwoBoneIK3D
var _targets: Array[Node3D] = []
var _head := -1
## Кисти на костях: BoneAttachment3D идёт за позой после IK (поза кости из скелета — до неё).
var _hands: Array[Node3D] = []
var _sword: Node3D
var _state := -1
var size := 1.0
var tempo := 1.0
## Оружие, которое держат руки модели (молот Кузнеца): узел прямо под Visual.
var _weapon: Node3D
var _grip_hands: GripHands
var _palms: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Скелет уже обновлялся и оружие лежит в ладони (до первого обновления ладоней ещё нет).
var holding := false
var _scene_pose := &""
## Насколько поднят сидящий, чтобы таз лёг на камень, а не ушёл в него.
var _seat_lift := 0.0
## Вампир: насколько раскрыт плащ-крылья (0…1) и разгорелись глаза — ведёт Vampire.
var spread := 0.0
var eyes_flare := 0.0
var _eyes: Array[MeshInstance3D] = []
var _eye_glow: StandardMaterial3D
var _eye_light: OmniLight3D
## Плащ-крылья: перепонка в мире, точки — кости после IK (шея, плечо, локоть, кисть, бедро, колено).
var _wing_mesh: MeshInstance3D
var _wing_bones: Array = []
var _neck: Node3D


static func build(enemy: Dummy, visual: Node3D, body_material: Material, model_look: StringName) -> EnemyModel:
	var model := EnemyModel.new()
	model.name = &"Model"
	model.look = model_look
	model._enemy = enemy
	visual.add_child(model)
	model._setup(body_material)
	return model


func _setup(body_material: Material) -> void:
	size = SIZE.get(look, 1.0)
	tempo = TEMPO.get(look, 1.0)
	lean = Node3D.new()
	lean.name = &"Lean"
	lean.scale = Vector3.ONE * size
	add_child(lean)
	hero = HeroModel.new()
	lean.add_child(hero)
	var mesh := hero.find_child("Mannequin", true, false) as MeshInstance3D
	if mesh:
		mesh.set_surface_override_material(0, body_material)
		if mesh.mesh.get_surface_count() > 1:
			mesh.set_surface_override_material(1, _flat(Color(0.12, 0.1, 0.1) if look == VAMPIRE else Color(0.22, 0.23, 0.26)))
	_head = hero.skeleton.find_bone("Head")
	_hands = [hero.hand.get_parent() as Node3D, _bone("LeftHand")]
	_dress()
	_rig_ik()
	_weapon = _enemy._grip
	if _weapon:
		# Кулак поперёк рукояти — после IK; оружие в ладони — по итоговой позе, как скелет обновился.
		_grip_hands = GripHands.new()
		_grip_hands.name = &"GripHands"
		hero.skeleton.add_child(_grip_hands)
		hero.skeleton.skeleton_updated.connect(_weapon_to_hand)


# --- Черты облика ----------------------------------------------------------------

func _dress() -> void:
	match look:
		SOLDIER:
			# Шлем-котелок с полями и меч в правой руке.
			var steel := _flat(Color(0.5, 0.52, 0.56), 0.6)
			var head := _bone("Head")
			head.add_child(_part(CylinderMesh, Vector3(0.24, 0.16, 0.24), Vector3(0.0, 0.16, 0.0), steel))
			head.add_child(_part(CylinderMesh, Vector3(0.34, 0.025, 0.34), Vector3(0.0, 0.09, 0.0), steel))
			_sword = Node3D.new()
			_sword.name = &"Sword"
			hero.hand.add_child(_sword)
			_sword.add_child(_part(BoxMesh, Vector3(0.05, 0.75, 0.015), Vector3(0.0, 0.45, 0.0), steel))
			_sword.add_child(_part(BoxMesh, Vector3(0.2, 0.035, 0.04), Vector3(0.0, 0.06, 0.0), _flat(Color(0.3, 0.24, 0.16))))
		BLACKSMITH:
			# Кожаный фартук кузнеца и наплечник из грубого железа.
			var leather := _flat(Color(0.2, 0.12, 0.07))
			var hips := _bone("Hips")
			hips.add_child(_part(BoxMesh, Vector3(0.36, 0.55, 0.03), Vector3(0.0, -0.18, 0.13), leather))
			var shoulder := _bone("RightShoulder")
			shoulder.add_child(_part(BoxMesh, Vector3(0.2, 0.08, 0.2), Vector3(0.0, 0.08, 0.0), _flat(Color(0.28, 0.27, 0.29), 0.5)))
		VAMPIRE:
			# Плащ до колен, высокий воротник, красные глаза.
			var cloth := _flat(Color(0.08, 0.03, 0.05))
			var chest := _bone("UpperChest")
			chest.add_child(_part(BoxMesh, Vector3(0.5, 1.15, 0.03), Vector3(0.0, -0.45, -0.17), cloth, Vector3(-0.12, 0.0, 0.0)))
			chest.add_child(_part(BoxMesh, Vector3(0.42, 0.3, 0.03), Vector3(0.0, 0.32, -0.12), _flat(Color(0.35, 0.02, 0.05)), Vector3(0.25, 0.0, 0.0)))
			var glow := _flat(Color(1.0, 0.1, 0.08))
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.1, 0.05)
			glow.emission_energy_multiplier = 4.0
			var head := _bone("Head")
			for x: float in [-0.035, 0.035]:
				var eye := _part(SphereMesh, Vector3(0.022, 0.022, 0.022), Vector3(x, 0.07, 0.1), glow)
				head.add_child(eye)
				_eyes.append(eye)
			_eye_glow = glow
			_eye_light = OmniLight3D.new()
			_eye_light.light_color = Color(1.0, 0.1, 0.05)
			_eye_light.light_energy = 0.0
			_eye_light.omni_range = 3.0
			_eye_light.position = Vector3(0.0, 0.07, 0.2)
			head.add_child(_eye_light)
			# Плащ-крылья: раскрытый плащ повёрнут к камере багровой подкладкой (как у Дракулы).
			var wing := _flat(Color(0.42, 0.02, 0.06))
			wing.emission_enabled = true
			wing.emission = Color(0.3, 0.0, 0.03)
			wing.emission_energy_multiplier = 0.6
			wing.cull_mode = BaseMaterial3D.CULL_DISABLED
			_wing_mesh = MeshInstance3D.new()
			_wing_mesh.name = &"CloakWings"
			_wing_mesh.mesh = ImmediateMesh.new()
			_wing_mesh.material_override = wing
			_wing_mesh.top_level = true
			_wing_mesh.visible = false
			add_child(_wing_mesh)
			_wing_mesh.global_transform = Transform3D.IDENTITY
			_neck = chest
			for side: String in ["Right", "Left"]:
				var bones: Array[Node3D] = []
				for part: String in ["UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"]:
					bones.append(_bone(side + part))
				_wing_bones.append(bones)


func _bone(bone: String) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = bone
	attachment.bone_name = bone
	hero.skeleton.add_child(attachment)
	return attachment


func _part(kind: Variant, size: Vector3, at: Vector3, material: Material, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh: PrimitiveMesh = kind.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x * 0.5
		(mesh as CylinderMesh).bottom_radius = size.x * 0.5
		(mesh as CylinderMesh).height = size.y
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x
		(mesh as SphereMesh).height = size.x * 2.0
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation = tilt
	return node


static func _flat(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.5 if metallic > 0.0 else 0.85
	return material


# --- Руки к глазам: IK поверх клипа ------------------------------------------------

func _rig_ik() -> void:
	_ik = TwoBoneIK3D.new()
	_ik.name = &"PalmsToEyes"
	hero.skeleton.add_child(_ik)
	_ik.set_setting_count(2)
	for i in 2:
		var side := "Right" if i == 0 else "Left"
		_ik.set_root_bone_name(i, side + "UpperArm")
		_ik.set_middle_bone_name(i, side + "LowerArm")
		_ik.set_end_bone_name(i, side + "Hand")
		var target := Node3D.new()
		target.name = side + "Palm"
		add_child(target)
		_targets.append(target)
		_ik.set_target_node(i, _ik.get_path_to(target))
		# Локти вниз: полюс под грудью, чуть вперёд и в свою сторону.
		var pole := Node3D.new()
		pole.name = side + "Elbow"
		lean.add_child(pole)
		pole.position = Vector3(0.35, 0.6, 0.35 if i == 0 else -0.35)
		_ik.set_pole_node(i, _ik.get_path_to(pole))
	_ik.influence = 0.0


## Где сейчас глаза (между глаз), в мире.
func eye_point() -> Vector3:
	var pose := hero.skeleton.get_bone_global_pose(_head)
	var forward := global_basis.x.normalized()
	return hero.skeleton.global_transform * pose.origin + Vector3.UP * 0.07 + forward * 0.08


## Где кисть (запястье) руки side (0 — правая), в мире — после IK.
func hand_point(side: int) -> Vector3:
	return _hands[side].global_position


## Меч в руке солдата (для тестов: оружие всегда в руке).
func sword() -> Node3D:
	return _sword


## Голова на кости — туда Кузнец сажает свои горящие глаза.
func head_attachment() -> Node3D:
	return _bone("Head")


## Середина ладони кисти side (0 — правая), в мире: через неё идёт рукоять. Поза кости после IK
## видна только в момент обновления скелета — поэтому ладони запоминаются там (_weapon_to_hand),
## в пространстве Visual: враг переехал (телепорт, сцена) — ладонь едет вместе с ним.
func palm_point(side: int) -> Vector3:
	return get_parent_node_3d().global_transform * _palms[side] if _grip_hands else hand_point(side)


## Скелет обновился: оружие ложится в ладонь правой кисти (первая точка хвата — в ладони).
func _weapon_to_hand() -> void:
	var to_visual := get_parent_node_3d().global_transform.affine_inverse()
	_palms = [to_visual * _grip_hands.palm(0), to_visual * _grip_hands.palm(1)]
	holding = true
	_weapon.position = _palms[0] - _weapon.basis * _enemy._grip_points()[0]


# --- Каждый кадр ---------------------------------------------------------------------

func update(delta: float) -> void:
	if look == VAMPIRE:
		_update_cloak()
	var enemy := _enemy
	var state := enemy.state
	var fresh := state != _state
	_state = state
	var t := enemy._state_time
	var rubbing := state == Dummy.State.BLINDED and enemy.blind_reaction == CreatureKind.Reaction.RUB_EYES
	# Сцена (сидит, на колене) — свой клип; таз на месте, хоть Visual и опущен для примитивов.
	var scene_pose := enemy._model_pose()
	if look == BLACKSMITH:
		# Примитивы Кузнеца в сценах опускают Visual (сел, встал на колено) — у манекена это делают
		# клипы, поэтому ноги остаются на земле.
		position.y = -enemy.visual.position.y + _seat(scene_pose == &"Sitting_Idle")
	if scene_pose != &"":
		if scene_pose == &"Fixing_Kneeling":
			_kneel(delta)
		else:
			hero.play(scene_pose, tempo)
		lean.rotation.z = 0.0
		_scene_pose = scene_pose
		_update_palms(false, t, delta)
		return
	if _scene_pose != &"":
		# Встаёт из сцены: плавный переход в обычную позу.
		_scene_pose = &""
		hero.play(&"Idle", tempo, SCENE_BLEND)
	if look == BLACKSMITH:
		_update_blacksmith(state, delta)
		_update_palms(rubbing, t, delta)
		lean.rotation.z = enemy.body_mesh.rotation.z * 0.5
		return
	var attack: Array = ATTACKS.get(look, ATTACKS[SOLDIER])
	var clip: StringName = attack[0]
	var length := hero.anim.get_animation(clip).length
	var hit: float = length * attack[1]
	match state:
		Dummy.State.WINDUP:
			if fresh:
				hero.play_span(clip, 0.0, hit, enemy.windup_time, 0.1)
		Dummy.State.ATTACK:
			if fresh:
				hero.play_span(clip, hit, length * 0.75, enemy.attack_time, 0.03)
		Dummy.State.RECOVER:
			if fresh:
				hero.play_span(clip, length * 0.75, 0.0, enemy.recover_time, 0.1)
		Dummy.State.STAGGER, Dummy.State.FLINCH:
			if fresh:
				hero.play_span(&"Hit_Chest", 0.0, 0.0, maxf(enemy.stagger_time if state == Dummy.State.STAGGER else enemy.flinch_time, 0.2), 0.05)
		Dummy.State.OFF_BALANCE:
			hero.play(&"Idle_Shield_Break")
		Dummy.State.CRITICAL_HIT:
			hero.hold(&"Hit_Chest", 0.25)
		Dummy.State.KNOCKDOWN:
			if fresh:
				hero.play_span(&"Hit_Knockback", 0.0, 0.0, enemy.knockdown_time, 0.05)
		Dummy.State.DEAD:
			if fresh:
				hero.play_span(&"Death01", 0.0, 0.0, 0.5, 0.05)
		Dummy.State.BLINDED:
			if rubbing:
				if enemy.blind_recoiling():
					if fresh:
						hero.play_span(&"Hit_Head", 0.0, 0.0, enemy._blind_recoil, 0.05)
				else:
					hero.play(&"Idle")
			else:
				# Вампир: потерян, шатается.
				hero.play(&"Idle_Shield_Break", 0.8)
		_:
			var speed := absf(enemy.velocity.x)
			if speed < 0.3:
				hero.play(&"Sword_Idle" if _sword else &"Idle")
			elif speed < WALK_SPEED * 1.3:
				hero.play(&"Walk", speed / WALK_SPEED)
			else:
				hero.play(&"Jog_Fwd", clampf(speed / JOG_SPEED, 0.7, 1.8))
	# Доигранный отрезок держит последний кадр (как у героя).
	if hero._clip_end > 0.0 and hero.anim.current_animation_position >= hero._clip_end:
		hero.anim.speed_scale = 0.0
	_update_palms(rubbing, t, delta)
	# Наклон тела врага (вздрог, стойка) — мягче: позу и так даёт клип.
	lean.rotation.z = enemy.body_mesh.rotation.z * 0.5


## Сидит: таз ложится на камень (Dummy._seat_height), а не уходит в него — подъём по позе таза.
func _seat(sitting: bool) -> float:
	if not sitting:
		_seat_lift = 0.0
		return 0.0
	var hips := hero.skeleton.global_transform * hero.skeleton.get_bone_global_pose(hero.skeleton.find_bone("Hips")).origin
	var want := _enemy.global_position.y + _enemy._seat_height() + SEAT_PELVIS * size
	_seat_lift += (want - hips.y) * 0.5
	return _seat_lift


## На колене: кадр клипа стоит, а переход в него идёт. У AnimationPlayer переход идёт со скоростью
## speed_scale — поэтому стоит сам клип (custom_speed 0), а не весь плеер. Без физики (статуя,
## delta 0) — сразу в позу.
func _kneel(delta: float) -> void:
	if hero._clip == &"Fixing_Kneeling":
		return
	hero._clip = &"Fixing_Kneeling"
	hero._clip_end = 0.0
	hero.anim.speed_scale = 1.0
	hero.anim.play(&"Fixing_Kneeling", KNEEL_BLEND if delta > 0.0 else 0.0, 0.0)
	hero.anim.seek(KNEEL_AT, true)


## Кузнец: тело — шаг и стойка, удары делает молот (поза — Blacksmith), руки на рукояти.
func _update_blacksmith(state: Dummy.State, delta: float) -> void:
	var enemy := _enemy
	var speed := absf(enemy.velocity.x)
	match state:
		Dummy.State.STAGGER, Dummy.State.FLINCH:
			hero.play(&"Hit_Chest", tempo)
		Dummy.State.KNOCKDOWN:
			hero.play(&"Hit_Knockback", tempo)
		Dummy.State.BLINDED:
			if enemy.blind_recoiling():
				hero.play(&"Hit_Head", tempo)
			else:
				hero.play(&"Idle", tempo)
		_:
			if speed < 0.3 or state in [Dummy.State.WINDUP, Dummy.State.ATTACK, Dummy.State.RECOVER]:
				hero.play(&"Idle", tempo)
			else:
				hero.play(&"Walk", speed / (WALK_SPEED * size))
	if state == Dummy.State.BLINDED and enemy.blind_reaction == CreatureKind.Reaction.RUB_EYES:
		# Придерживает молот одной рукой навершием в землю (Dummy._blind_weapon_angle).
		_weapon.rotation.z = lerp_angle(_weapon.rotation.z, enemy._blind_weapon_angle(), 1.0 - exp(-8.0 * delta))


## Руки на рукояти (IK, пространство Visual). Хват — от груди в сторону молота, но не ниже, чем
## позволяет пол под навершием: опущенный молот упирается в землю, а не в неё. Молот опущен —
## правая держит одна, левая висит; поднят — обе на древке. В слепоте правая держит его опущенным,
## левая трёт глаза. Кулак поперёк рукояти — GripHands; сам молот кладёт в ладонь _weapon_to_hand.
func _hold_weapon(rubbing: bool, t: float) -> void:
	_ik.influence = 1.0
	var visual := get_parent_node_3d()
	var points := _enemy._grip_points()
	var angle := _weapon.rotation.z
	var along := Vector3(-sin(angle), cos(angle), 0.0)
	var floor_y := -_enemy.visual.position.y
	var reach := _enemy._weapon_tip().y - points[0].y
	var grip := Vector3(0.0, position.y + CHEST_Y * size, SHOULDER_Z * size) + along * GRIP_RADIUS * size
	grip.y = maxf(grip.y, floor_y - along.y * reach + 0.04)
	_targets[0].global_position = visual.global_transform * _wrist_for(grip, 1.0)
	var world_axis := (visual.global_basis * along).normalized()
	_grip_hands.axes[0] = world_axis
	var two_hands := along.y > -0.5 and not rubbing and points.size() > 1
	_grip_hands.axes[1] = world_axis if two_hands else Vector3.ZERO
	if two_hands:
		_targets[1].global_position = visual.global_transform * _wrist_for(grip + along * (points[1].y - points[0].y), -1.0)
	elif rubbing:
		var rub := Vector3.UP * sin(t * 9.0) * 0.04
		_targets[1].global_position = eye_point() + global_basis.x.normalized() * PALM_AHEAD * size - Vector3.UP * PALM_DROP + rub
	else:
		# Левая свободна: висит у бедра.
		_targets[1].global_position = visual.global_transform * Vector3(0.08 * size, position.y + 0.78 * size, -SHOULDER_Z * size * 1.2)


## Куда вести запястье, чтобы середина ладони легла в точку palm (пространство Visual).
func _wrist_for(palm: Vector3, side: float) -> Vector3:
	var shoulder := Vector3(0.0, position.y + SHOULDER_Y * size, SHOULDER_Z * size * side)
	return palm - (palm - shoulder).normalized() * PALM_FROM_WRIST * size


## Ладони к глазам и трут; меч в это время — вдоль кисти и предплечья (§6.2).
## У кого руки держат оружие (Кузнец), IK ведёт их к рукояти, а в слепоте одна рука
## держит оружие опущенным, другая трёт глаза.
func _update_palms(rubbing: bool, t: float, delta: float) -> void:
	if _weapon:
		_hold_weapon(rubbing, t)
		return
	if spread > 0.001:
		# Руки раскинуты в стороны и чуть вверх — держат края плаща.
		_ik.influence = spread
		var side := global_basis.z.normalized()
		for i in 2:
			var shoulder: Vector3 = (_wing_bones[i][0] as Node3D).global_position
			_targets[i].global_position = shoulder + side * (0.6 if i == 0 else -0.6) * size + Vector3.UP * 0.25 * size
		return
	var want := 1.0 if rubbing and t > 0.12 else 0.0
	_ik.influence = move_toward(_ik.influence, want, delta * (6.0 if want > 0.0 else 3.0))
	if _ik.influence > 0.0:
		var eyes := eye_point()
		var forward := global_basis.x.normalized()
		var side := global_basis.z.normalized()
		var rub := (Vector3.UP * sin(t * 9.0) * 0.03 + forward * cos(t * 9.0) * 0.015) * _ik.influence
		for i in 2:
			var out := side * (PALM_SPREAD if i == 0 else -PALM_SPREAD)
			_targets[i].global_position = eyes + forward * PALM_AHEAD - Vector3.UP * PALM_DROP + out + (rub if i == 0 else -rub)
	if hero.hand:
		var along := Vector3.ZERO if rubbing else HeroModel.GRIP_ROTATION
		hero.hand.rotation = hero.hand.rotation.lerp(along, 1.0 - exp(-10.0 * delta))


## Глаза и плащ-крылья вампира: перепонка от шеи по руке до кисти и вниз к колену.
func _update_cloak() -> void:
	if _eye_light == null:
		return
	_eye_light.light_energy = eyes_flare * 3.0
	_eye_glow.emission_energy_multiplier = 4.0 + eyes_flare * 16.0
	for eye in _eyes:
		eye.scale = Vector3.ONE * (1.0 + eyes_flare * 1.5)
	_wing_mesh.visible = spread > 0.02 and is_visible_in_tree()
	var mesh := _wing_mesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if not _wing_mesh.visible:
		return
	# Чуть за спиной: плащ не режет тело.
	var back := -global_basis.x.normalized() * 0.06 * size
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for bones: Array in _wing_bones:
		var shoulder: Vector3 = (bones[0] as Node3D).global_position
		var elbow: Vector3 = (bones[1] as Node3D).global_position
		var hand: Vector3 = (bones[2] as Node3D).global_position
		var hip: Vector3 = (bones[3] as Node3D).global_position
		var knee: Vector3 = (bones[4] as Node3D).global_position
		var foot: Vector3 = (bones[5] as Node3D).global_position
		# Край плаща дальше кисти; низ — до лодыжек, по краю провисает к телу фестонами.
		var tip := hand + (hand - elbow).normalized() * 0.25 * size
		var ankle := knee.lerp(foot, 0.8)
		var hem := ankle.lerp(tip, 0.5).lerp(hip, 0.15)
		var neck := _neck.global_position
		var ring := [neck, shoulder, elbow, tip, hem, ankle, knee]
		for i in range(ring.size() - 1):
			for p: Vector3 in [hip, ring[i], ring[i + 1]]:
				mesh.surface_set_normal(Vector3.BACK)
				mesh.surface_add_vertex(p + back)
	mesh.surface_end()
