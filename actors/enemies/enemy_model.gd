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

const SOLDIER := &"soldier"
const VAMPIRE := &"vampire"
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


static func build(enemy: Dummy, visual: Node3D, body_material: Material, model_look: StringName) -> EnemyModel:
	var model := EnemyModel.new()
	model.name = &"Model"
	model.look = model_look
	model._enemy = enemy
	visual.add_child(model)
	model._setup(body_material)
	return model


func _setup(body_material: Material) -> void:
	lean = Node3D.new()
	lean.name = &"Lean"
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
				head.add_child(_part(SphereMesh, Vector3(0.022, 0.022, 0.022), Vector3(x, 0.07, 0.1), glow))


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


# --- Каждый кадр ---------------------------------------------------------------------

func update(delta: float) -> void:
	var enemy := _enemy
	var state := enemy.state
	var fresh := state != _state
	_state = state
	var t := enemy._state_time
	var rubbing := state == Dummy.State.BLINDED and enemy.blind_reaction == CreatureKind.Reaction.RUB_EYES
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


## Ладони к глазам и трут; меч в это время — вдоль кисти и предплечья (§6.2).
func _update_palms(rubbing: bool, t: float, delta: float) -> void:
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
