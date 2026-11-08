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
## Удар в воздухе (2026-11-09, по замечанию автора): вертикальный, снизу вверх, и только
## верхом тела — ноги держат позу прыжка. Клип без костей ног собирается на лету.
const AIR_CLIP := &"Sword_Regular_A"
const AIR_FROM := 0.15
const LOWER_BODY: Array[String] = [
	"Root", "Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
]

var anim: AnimationPlayer
var skeleton: Skeleton3D
## Держатель оружия в правой руке — туда PlayerArms кладёт видимую копию клинка.
var hand: Node3D
var _clip := &""
var _clip_end := 0.0


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
	hand = skeleton.find_child("Grip", true, false) as Node3D
	if hand == null:
		var bone := BoneAttachment3D.new()
		bone.name = &"RightHand"
		bone.bone_name = "RightHand"
		skeleton.add_child(bone)
		hand = Node3D.new()
		hand.name = &"Grip"
		hand.rotation = GRIP_ROTATION
		hand.position = GRIP_OFFSET
		bone.add_child(hand)
	play(&"Idle")


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


## Застыть на кадре клипа (вис на уступе, заряд, блок).
func hold(clip: StringName, at: float, blend := BLEND) -> void:
	if clip != _clip:
		_clip = clip
		anim.play(clip, blend)
	_clip_end = 0.0
	anim.speed_scale = 0.0
	anim.seek(at, true)


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
	var vx := absf(player.velocity.x)
	match player.state:
		Player.State.MOVE:
			if not player.is_on_floor():
				play(&"Jump_Start" if player.velocity.y > 2.0 else &"Jump")
			elif vx < 0.3:
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
				play(&"Idle_Shield")
			else:
				hold(&"Sword_Block", 0.35)
		Player.State.DEAD:
			if _clip != &"Death01":
				play_span(&"Death01", 0.0, 0.0, 1.6, 0.1)
		Player.State.DRINK:
			play(&"Consume")
		Player.State.THROW:
			play(&"OverhandThrow", 1.6)
		Player.State.BOW:
			play(&"Pistol_Aim_Neutral")
		Player.State.CHARGE:
			hold(&"Sword_Dash", 0.25)
		Player.State.PLUNGE:
			play(&"Jump")
