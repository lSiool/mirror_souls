class_name HeroModel
extends Node3D
## Манекен героя (§3.3, 2026-11-09): гуманоид на стандартном скелете Godot вместо капсулы.
## Модель и анимации — Quaternius Universal Animation Library 1 и 2 (CC0); кости при импорте
## переименованы в профиль SkeletonProfileHumanoid (tools/characters/setup_mannequin.py),
## поэтому клипы потом лягут на модель автора с тем же профилем.
##
## Модель только показывает: столкновения, хитбоксы и тайминги остаются у Player и AttackStep.
## Клип удара и его отрезок — в AttackStep (anim, anim_from, anim_to): отрезок растягивается
## на длительность стадии, так удар модели попадает в активное окно хитбокса.

const MODEL := preload("res://assets/characters/mannequin/ual1.glb")
const EXTRA := preload("res://assets/characters/mannequin/ual2.glb")
## Рост модели 1.83 м, капсула героя — 1.8.
const SCALE := 0.98
const BLEND := 0.12
## Скорость бега, под которую снят цикл Jog_Fwd, и шага — под Walk.
const JOG_SPEED := 4.0
const WALK_SPEED := 1.6
## Удары серии без своего клипа — по номеру стадии.
const COMBO_ANIMS: Array[StringName] = [&"Sword_Regular_B", &"Sword_Regular_A", &"Sword_Regular_B"]
## Меч в кулаке: поворот и сдвиг от кости кисти (подобраны по снимкам tools/characters/hero_snapshot.gd).
const GRIP_ROTATION := Vector3(0.0, 0.0, -PI * 0.5)
const GRIP_OFFSET := Vector3(0.0, 0.08, 0.02)
## Щит и лук на модели (подобраны по снимкам tools/characters/hero_snapshot.gd): лицо щита —
## его ось +X, клинок лука — ось +Y.
## Поворот (рад) и сдвиг от кости.
const SHIELD_ON_ARM := [Vector3(0.0, PI, 0.0), Vector3(-0.1, 0.16, 0.0)]
const SHIELD_ON_BACK := [Vector3(0.0, PI * 0.5, 0.0), Vector3(0.0, 0.05, -0.2)]
const BOW_IN_HAND := [Vector3(0.0, 0.0, PI * 0.5), Vector3(0.0, 0.06, 0.0)]
## Удар в воздухе (2026-11-09, по замечанию автора): вертикальный, снизу вверх, и только
## верхом тела — ноги держат позу прыжка. Клип без костей ног собирается на лету.
const AIR_CLIP := &"Sword_Regular_A"
## На сколько манекен на лестнице придвинут к ней (м, в мире).
const LADDER_CLOSE := 0.22
## Парирование (§6.1, 2026-11-11): клип, отрезок встречного взмаха [от, до] и до куда доигрывает
## удачное парирование. Щитом — выпад щита навстречу удару, оружием — отбив снизу вверх.
## Играет только верх тела: ноги стоят как стояли.
const PARRY_SHIELD := [&"Shield_OneShot", 0.3, 0.62, 0.83]
const PARRY_BLADE := [&"Melee_Hook", 0.0, 0.3, 0.47]
## Сколько держится доигрыш удачного парирования.
const PARRY_HIT_TIME := 0.3
const AIR_FROM := 0.15
const LOWER_BODY: Array[String] = [
	"Root", "Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
]

var anim: AnimationPlayer
var skeleton: Skeleton3D
## Держатель оружия в правой руке — туда PlayerArms кладёт видимую копию клинка.
var hand: Node3D
## Щит на левом предплечье, щит за спиной, лук в левой руке — туда PlayerArms переносит
## свои щит и лук (§3.3).
var shield_mount: Node3D
var back_mount: Node3D
var bow_grip: Node3D
var _clip := &""
var _clip_end := 0.0
## Руки и ноги на перекладинах (лестница, §3.3) — создаётся при первом подъёме.
var _ladder: LadderLimbs
## Сколько ещё играет взмах парирования — поза блока его не перебивает.
var _parry_left := 0.0
## Свободная (левая) рука к точке — ладонь на кристалле осколка; создаётся при первом касании.
var _touch_ik: TwoBoneIK3D
var _touch_target: Node3D
var _touch_pole: Node3D


func _ready() -> void:
	# Копия облика (отзвук героя, отражение у осколка) приходит уже с моделью.
	var model := get_child(0) as Node3D if get_child_count() > 0 else null
	if model == null:
		model = MODEL.instantiate() as Node3D
		add_child(model)
	# Модель glTF смотрит в +Z, герой — вправо (+X).
	rotation.y = PI * 0.5
	scale = Vector3.ONE * SCALE
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	_merge_extra()
	# Кости без дорожки в клипе держат прежнюю позу, а не встают в покой: удар верхом тела
	# в воздухе оставляет ноги в позе прыжка.
	anim.deterministic = false
	hand = _mount(&"RightHand", &"Grip", [GRIP_ROTATION, GRIP_OFFSET])
	shield_mount = _mount(&"LeftLowerArm", &"ShieldMount", SHIELD_ON_ARM)
	back_mount = _mount(&"UpperChest", &"BackMount", SHIELD_ON_BACK)
	bow_grip = _mount(&"LeftHand", &"BowGrip", BOW_IN_HAND)
	play(&"Idle")


## Точка на кости: узел-держатель со сдвигом. У копии облика она уже есть — берём её.
func _mount(bone_name: StringName, mount_name: StringName, at: Array) -> Node3D:
	var mount := skeleton.find_child(String(mount_name), true, false) as Node3D
	if mount:
		return mount
	var bone := BoneAttachment3D.new()
	bone.name = bone_name
	bone.bone_name = String(bone_name)
	skeleton.add_child(bone)
	mount = Node3D.new()
	mount.name = mount_name
	mount.rotation = at[0]
	mount.position = at[1]
	bone.add_child(mount)
	return mount


## Клипы второго набора — в общую библиотеку: скелет у них один.
func _merge_extra() -> void:
	var lib := anim.get_animation_library(&"")
	# Библиотека общая для всех копий модели: второй раз сливать не нужно.
	if lib.has_animation(&"Consume"):
		return
	var extra := EXTRA.instantiate()
	var from := (extra.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation_library(&"")
	for clip in from.get_animation_list():
		if not lib.has_animation(clip):
			lib.add_animation(clip, from.get_animation(clip))
	extra.free()


## Зацикленный или долгий клип; тот же клип не перезапускается, только меняет скорость.
func play(clip: StringName, speed := 1.0, blend := BLEND) -> void:
	if clip == _clip and anim.is_playing():
		anim.speed_scale = speed
		return
	_clip = clip
	_clip_end = 0.0
	anim.speed_scale = speed
	anim.play(clip, blend)


## Отрезок клипа [from, to] растягивается на time секунд; to = 0 — до конца клипа.
func play_span(clip: StringName, from: float, to: float, time: float, blend := 0.08) -> void:
	if not anim.has_animation(clip):
		return
	var length := anim.get_animation(clip).length
	var end := to if to > from else length
	_clip = clip
	_clip_end = end
	anim.speed_scale = (end - from) / maxf(time, 0.05)
	anim.play(clip, blend)
	anim.seek(from, true)


## Застыть на кадре клипа (вис на уступе, заряд, блок, прицел). Играется клип-поза из одного кадра:
## у остановленного клипа (speed_scale = 0) не идёт и переход, и модель оставалась в прежней стойке.
func hold(clip: StringName, at: float, blend := BLEND) -> void:
	play(_frozen(clip, at), 1.0, blend)


## Клип-поза: кадр клипа на времени at, зацикленный.
func _frozen(clip: StringName, at: float) -> StringName:
	var pose := StringName("%s@%.2f" % [clip, at])
	var lib := anim.get_animation_library(&"")
	if lib.has_animation(pose) or not anim.has_animation(clip):
		return pose if lib.has_animation(pose) else clip
	var from := anim.get_animation(clip)
	var still := Animation.new()
	still.length = 0.2
	still.loop_mode = Animation.LOOP_LINEAR
	for track in from.get_track_count():
		var kind := from.track_get_type(track)
		var value: Variant
		match kind:
			Animation.TYPE_POSITION_3D: value = from.position_track_interpolate(track, at)
			Animation.TYPE_ROTATION_3D: value = from.rotation_track_interpolate(track, at)
			Animation.TYPE_SCALE_3D: value = from.scale_track_interpolate(track, at)
			_: continue
		var to := still.add_track(kind)
		still.track_set_path(to, from.track_get_path(track))
		match kind:
			Animation.TYPE_POSITION_3D: still.position_track_insert_key(to, 0.0, value)
			Animation.TYPE_ROTATION_3D: still.rotation_track_insert_key(to, 0.0, value)
			Animation.TYPE_SCALE_3D: still.scale_track_insert_key(to, 0.0, value)
	lib.add_animation(pose, still)
	return pose


## Удар: клип стадии, иначе — по номеру в серии.
## В воздухе — всегда вертикальный удар снизу верхом тела.
func attack(step: AttackStep, index: int, airborne := false) -> void:
	if airborne:
		play_span(_upper(AIR_CLIP), AIR_FROM, 0.0, step.duration)
		return
	var clip := step.anim
	if clip == &"":
		clip = COMBO_ANIMS[clampi(index - 1, 0, COMBO_ANIMS.size() - 1)]
	play_span(clip, step.anim_from, step.anim_to, step.duration)


## Копия клипа без костей ног и таза — только верх тела.
func _upper(clip: StringName) -> StringName:
	var upper := StringName(String(clip) + "_Upper")
	var lib := anim.get_animation_library(&"")
	if not lib.has_animation(upper):
		var copy := anim.get_animation(clip).duplicate(true) as Animation
		for track in range(copy.get_track_count() - 1, -1, -1):
			if String(copy.track_get_path(track).get_concatenated_subnames()) in LOWER_BODY:
				copy.remove_track(track)
		lib.add_animation(upper, copy)
	return upper


## Каждый кадр: поза по состоянию героя. Удары запускает сигнал attack_step_started.
func update(player: Player) -> void:
	# Отрезок клипа доигран — держим последний кадр, а не уходим в начало.
	if _clip_end > 0.0 and anim.current_animation_position >= _clip_end:
		anim.speed_scale = 0.0
	# Рост и сложение по возрасту (§1.3), как у капсулы.
	scale = AgeLook.body_scale(player.stats.current_age) * SCALE
	if player.lying:
		# Лежит (пробуждение в хижине): первый кадр «встать с пола».
		hold(&"LayToIdle", 0.0)
		return
	if player.sitting:
		# Сидит у осколка: очнулся после гибели на уровне-забеге (§8.11).
		play(&"Sitting_Idle")
		return
	if player.state == Player.State.LADDER and player.ladder:
		_on_ladder(player)
		return
	_off_ladder()
	_touch(player.touching)
	if _parry_left > 0.0:
		_parry_left -= get_physics_process_delta_time()
		if player.state in [Player.State.MOVE, Player.State.BLOCK]:
			return
		_parry_left = 0.0
	var vx := absf(player.velocity.x)
	match player.state:
		Player.State.MOVE:
			if not player.is_on_floor():
				play(&"Jump_Start" if player.velocity.y > 2.0 else &"Jump")
			elif vx < 0.3:
				# Со щитом — щитовая стойка: предплечье со щитом поднято перед корпусом.
				# У осколка — смирно, ладонь на кристалле.
				if player.touching:
					play(&"Idle")
				elif player.shield_in_hand():
					play(&"Idle_Shield")
				else:
					play(&"Sword_Idle" if player.arms.armed else &"Idle")
			elif vx < WALK_SPEED * 1.3:
				play(&"Walk", vx / WALK_SPEED)
			else:
				play(&"Jog_Fwd", clampf(vx / JOG_SPEED, 0.7, 1.8))
		Player.State.ROLL:
			if _clip != &"Roll":
				play_span(&"Roll", 0.12, 1.05, player.stats.roll_duration, 0.05)
		Player.State.SLIDE:
			play(&"Slide")
		Player.State.CLIMB, Player.State.LADDER:
			play(&"ClimbUp_1m", 0.6 if vx + absf(player.velocity.y) > 0.2 else 0.0)
		Player.State.LEDGE_HANG:
			hold(&"ClimbUp_1m", 0.0)
		Player.State.LEDGE_CLIMB:
			if _clip != &"ClimbUp_1m" or anim.speed_scale == 0.0:
				play_span(&"ClimbUp_1m", 0.0, 0.0, 0.35)
		Player.State.HURT:
			if _clip != &"Hit_Chest":
				play_span(&"Hit_Chest", 0.0, 0.0, 0.3, 0.05)
		Player.State.GUARD_BROKEN:
			play(&"Idle_Shield_Break")
		Player.State.BLOCK:
			if player.shield_in_hand():
				# Щит выставлен вперёд на вытянутой руке.
				hold(&"Shield_OneShot", 0.5)
			else:
				hold(&"Sword_Block", 0.35)
		Player.State.DEAD:
			if _clip != &"Death01":
				play_span(&"Death01", 0.0, 0.0, 1.6, 0.1)
		Player.State.DRINK:
			play(&"Consume")
		Player.State.THROW:
			play(&"OverhandThrow", 1.6)
		Player.State.CAST:
			# Посох вперёд — вспышка на cast_time (§6.2).
			if _clip != &"Spell_Simple_Shoot":
				play_span(&"Spell_Simple_Shoot", 0.0, 0.0, player._cast_spell.duration, 0.06)
		Player.State.BOW:
			# Поза прицела: вверх, прямо, вниз.
			var aim := player._aim_angle()
			hold(&"Pistol_Aim_Up" if aim > 0.4 else (&"Pistol_Aim_Down" if aim < -0.4 else &"Pistol_Aim_Neutral"), 0.0)
		Player.State.CHARGE:
			hold(&"Sword_Dash", 0.25)
		Player.State.PLUNGE:
			play(&"Jump")


## Лестница: лицом к ней, спиной к камере; основа — стойка, руки и ноги — на перекладинах (IK).
func _on_ladder(player: Player) -> void:
	if _ladder == null:
		_ladder = LadderLimbs.new()
		_ladder.name = &"LadderLimbs"
		add_child(_ladder)
		_ladder.rig(skeleton)
	hold(&"Idle", 0.0)
	# Модель смотрит в +Z; к лестнице — это мировой -Z, при любом развороте героя.
	var parent_yaw := (get_parent() as Node3D).global_rotation.y
	rotation.y = PI - parent_yaw
	position = (get_parent() as Node3D).global_basis.inverse() * Vector3(0.0, 0.0, -LADDER_CLOSE)
	_ladder.climb(player.ladder, player.global_position, player.velocity.y, get_physics_process_delta_time())


func _off_ladder() -> void:
	if _ladder == null or position == Vector3.ZERO:
		return
	_ladder.release()
	rotation.y = PI * 0.5
	position = Vector3.ZERO


## Ладонь на кристалле осколка (§8.4, 2026-11-10): герой стоит смирно, левая рука — свободная, меч
## остаётся в правой — тянется к кристаллу. Нет кристалла — рука отпущена.
func _touch(crystal: Node3D) -> void:
	if crystal == null or not is_instance_valid(crystal):
		if _touch_ik:
			_touch_ik.influence = 0.0
		return
	if _touch_ik == null:
		_touch_ik = TwoBoneIK3D.new()
		_touch_ik.name = &"TouchIK"
		skeleton.add_child(_touch_ik)
		_touch_ik.set_setting_count(1)
		_touch_ik.set_root_bone_name(0, "LeftUpperArm")
		_touch_ik.set_middle_bone_name(0, "LeftLowerArm")
		_touch_ik.set_end_bone_name(0, "LeftHand")
		_touch_target = Node3D.new()
		_touch_target.top_level = true
		add_child(_touch_target)
		_touch_pole = Node3D.new()
		_touch_pole.top_level = true
		add_child(_touch_pole)
		_touch_ik.set_target_node(0, _touch_ik.get_path_to(_touch_target))
		_touch_ik.set_pole_node(0, _touch_ik.get_path_to(_touch_pole))
	# Ладонь — на ближней к герою грани кристалла, чуть ниже середины; локоть — вниз и наружу.
	var side := signf(crystal.global_position.x - global_position.x)
	var at := crystal.global_position + Vector3(-side * 0.18, -0.12, 0.08)
	_touch_target.global_position = at
	_touch_pole.global_position = global_position + Vector3(side * 0.1, 0.6, -0.8)
	_touch_ik.influence = 1.0


## Нажат блок, герой умеет парировать: встречный взмах на окно парирования.
func parry(shield: bool, window: float) -> void:
	var move: Array = PARRY_SHIELD if shield else PARRY_BLADE
	play_span(_upper(move[0]), move[1], move[2], window, 0.04)
	_parry_left = window


## Удар отбит: взмах доигрывает до конца — враг раскрыт.
func parry_hit(shield: bool) -> void:
	var move: Array = PARRY_SHIELD if shield else PARRY_BLADE
	play_span(_upper(move[0]), move[2], move[3], PARRY_HIT_TIME, 0.02)
	_parry_left = PARRY_HIT_TIME
