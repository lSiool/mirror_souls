class_name Blacksmith
extends Dummy
## Босс: Безмолвный Кузнец (§6.3). Проклятый старый знакомый кузнеца из часовни: в полтора раза выше
## человека, изуродован, не издаёт ни звука. Медленный и неумолимый: долго разворачивается, идёт
## тяжело, волочит молот. Вес молота — в ритме: долгий замах, пауза наверху, резкое падение,
## и молот застревает в камне (окно для ответа). Сбитая стойкость ставит его на колено — добивание.
##
## Вступление (seated): сидит на камне среди черепов; герой подходит — из воздуха закручивается
## дух и входит в тело, загораются глаза, он встаёт. На 55 % здоровья — вторая фаза: падает
## на колено, дух вырывается и возвращается, молот горит фиолетовым, кольцо отбрасывает героя.
##
## Фаза 1: боковой; удар сверху с волной; серия «боковой, боковой, сверху с задержкой»;
## волок — тащит молот с искрами и бьёт снизу.
## Фаза 2 добавляет: прыжок на героя с кольцом волн, три удара сверху подряд, руки духа из земли.
## Побеждён один раз за игру (boss_flag).

const WAVE_SPEED := 9.0
const WAVE_TIME := 0.8
const WAVE_DAMAGE := 14.0
const PHASE_AT := 0.55
const PHASE_SPEEDUP := 0.8
const INTRO_RANGE := 7.0
const SPIRIT_COLOR := Color(0.55, 0.3, 0.95)
const HUMAN_COLOR := Color(0.42, 0.33, 0.28)
const LEAP_UP := 13.0
const LEAP_AIR := 0.85
const LEAP_MAX_X := 12.0
const DRAG_SPEED := 8.0
const DRAG_TIME := 0.75
const HAND_WARN := 0.9
const HAND_DAMAGE := 18.0
const RING_DAMAGE := 8.0
## Наклон молота (радианы от вертикали, вперёд — минус): волочится по земле за спиной, заведён
## над головой или назад, пришёл в пол или вперёд на уровень груди.
const POSE_DRAG := 2.5
const POSE_OVERHEAD := 0.35
const POSE_BACK := 1.7
const POSE_FLOOR := -2.5
const POSE_SWEPT := -1.9
## Поза на коленях после смерти: в ней он застывает.
const KNEEL_Y := -0.8
const KNEEL_TILT := -0.45
## Стеклянная статуя: цвет, отсвет; сколько после смерти он человек, сколько стекленеет,
## через сколько после этого летят отзвуки.
const STATUE_COLOR := Color(0.7, 0.85, 1.0, 0.62)
const STATUE_GLOW := Color(0.45, 0.7, 1.0)
const STATUE_DELAY := 2.0
const STATUE_TIME := 1.8
const STATUE_LOOT_DELAY := 0.5
## Насколько впереди статуи ложится отзвук босса.
const LOOT_AHEAD := 1.3

enum Blow { SWEEP, SLAM, SLAM_HELD, SLAM_BIG, DRAG, LEAP, HANDS }

const COOLDOWNS := {Blow.DRAG: 6.0, Blow.LEAP: 7.0, Blow.HANDS: 9.0}

## Флаг мира «побеждён»: открывает Главное Зеркало, отдых его не воскрешает.
@export var boss_flag: StringName = &"boss_smith"
## Отзвуки и мастерство отданы — после того как он застыл статуей. Не стоит при новом заходе —
## отдать сразу (герой ушёл, пока тело стекленело).
@export var loot_flag: StringName = &"boss_smith_loot"
@export var boss_name := "Безмолвный Кузнец"
@export var sweep_windup := 0.85
@export var slam_windup := 1.35
## Сколько молот сидит в камне после удара сверху и сколько возвращается после бокового.
@export var slam_stuck := 1.5
@export var sweep_recover := 0.9
## Сидит на камне, пока герой не подойдёт (кадр 6).
@export var seated := false

var phase := 1
var _blow := Blow.SWEEP
var _chain: Array[Blow] = []
var _engaged := false
var _scene_running := false
var _cooldowns := {}
var _leap_x := 0.0
var _spark_t := 0.0
var _trail_t := 0.0
var _pattern := 0
## Застыл стеклом.
var statue := false

@onready var hammer: Node3D = $Visual/Hammer
@onready var hammer_head: MeshInstance3D = $Visual/Hammer/Head
@onready var eyes: Array[Node3D] = [$Visual/Head/EyeA, $Visual/Head/EyeB]


func _init() -> void:
	creature = CreatureKind.Kind.CURSED


func _ready() -> void:
	super()
	leaves_statue = true
	if GameState.has_flag(boss_flag):
		_stand_as_statue()
		return
	for blow: Blow in COOLDOWNS:
		_cooldowns[blow] = 2.0
	if seated:
		for eye in eyes:
			eye.visible = false
		visual.position.y = -0.95
		body_mesh.rotation.z = -0.35
		hammer.rotation.z = POSE_OVERHEAD * 0.4


func _grip_node() -> Node3D:
	return get_node_or_null(^"Visual/Hammer") as Node3D


func _two_handed_grip() -> bool:
	return true


## Ослеп: молот отпущен, руки к глазам.
func _carry_grip_when_blind() -> bool:
	return false


# --- Вступление и вторая фаза --------------------------------------------------

func _wake_check(_delta: float) -> void:
	if _scene_running or _engaged:
		return
	_find_player()
	if _player and absf(_player.global_position.x - global_position.x) < INTRO_RANGE:
		_play_intro()


func _play_intro() -> void:
	_scene_running = true
	facing = signf(_player.global_position.x - global_position.x)
	visual.rotation.y = 0.0 if facing > 0.0 else PI
	await _spirit(true)
	for eye in eyes:
		eye.visible = true
	var rise := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	rise.tween_property(visual, "position:y", 0.0, 0.9)
	rise.tween_property(body_mesh, "rotation:z", 0.0, 0.9)
	await rise.finished
	Events.camera_shake_requested.emit(0.6, 0.6)
	_engaged = true
	Events.boss_engaged.emit(self)
	_scene_running = false
	_set_state(State.CHASE)


## Вторая фаза: на колено, дух вырывается и возвращается, молот загорается, кольцо отбрасывает.
func _transition() -> void:
	phase = 2
	_scene_running = true
	_chain.clear()
	attack_hitbox.active = false
	hurtbox.invulnerable = true
	_set_state(State.DORMANT)
	var kneel := create_tween().set_parallel(true)
	kneel.tween_property(visual, "position:y", -0.6, 0.35)
	kneel.tween_property(body_mesh, "rotation:z", -0.4, 0.35)
	kneel.tween_property(hammer, "rotation:z", POSE_FLOOR, 0.35)
	await kneel.finished
	await _spirit(false)
	await _spirit(true)
	for arena in get_tree().get_nodes_in_group("boss_arena"):
		arena.flare()
	_ignite()
	_ring(global_position + Vector3(0.0, 0.2, -0.3), SPIRIT_COLOR, 7.0)
	_burst_hitbox(Vector3(14.0, 3.0, 4.0), RING_DAMAGE, 13.0)
	Events.camera_shake_requested.emit(0.9, 0.6)
	HitStop.stop(0.08)
	var stand := create_tween().set_parallel(true)
	stand.tween_property(visual, "position:y", 0.0, 0.5)
	stand.tween_property(body_mesh, "rotation:z", 0.0, 0.5)
	await stand.finished
	hurtbox.invulnerable = false
	poise = max_poise
	_scene_running = false
	_set_state(State.CHASE)


## Дух: в тело (into) — спираль из воздуха в грудь; из тела — вверх и в сторону.
func _spirit(into: bool) -> void:
	var spirit := Node3D.new()
	get_parent().add_child(spirit)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(SPIRIT_COLOR, 0.55)
	var ghost := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = 0.45
	shape.height = 2.4
	shape.material = material
	ghost.mesh = shape
	ghost.rotation.z = PI * 0.5
	spirit.add_child(ghost)
	var eye_material := StandardMaterial3D.new()
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_material.albedo_color = Color(0.85, 0.75, 1.0)
	for side in [-0.14, 0.14]:
		var eye := MeshInstance3D.new()
		var dot := BoxMesh.new()
		dot.size = Vector3(0.1, 0.08, 0.1)
		dot.material = eye_material
		eye.mesh = dot
		eye.position = Vector3(1.0, side, 0.3)
		spirit.add_child(eye)
	var trail := CPUParticles3D.new()
	var speck := BoxMesh.new()
	speck.size = Vector3(0.14, 0.14, 0.14)
	speck.material = material
	trail.mesh = speck
	trail.amount = 60
	trail.lifetime = 0.9
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.5
	trail.gravity = Vector3(0.0, 0.4, 0.0)
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.6
	spirit.add_child(trail)
	var chest := global_position + Vector3(0.0, 1.6, -0.6)
	var swirl := func(t: float) -> void:
		var s := t if into else 1.0 - t
		var radius := lerpf(4.5, 0.0, s)
		var angle := s * TAU * 2.2
		spirit.global_position = chest + Vector3(cos(angle) * radius, lerpf(5.5, 0.0, s), sin(angle) * radius * 0.6)
		spirit.rotation.y = -angle
	var tween := create_tween()
	tween.tween_method(swirl, 0.0, 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN if into else Tween.EASE_OUT)
	await tween.finished
	if into:
		HitSpark.spawn(get_parent(), chest, SPIRIT_COLOR, 30)
		Events.camera_shake_requested.emit(0.35, 0.3)
	trail.emitting = false
	var fade := spirit.create_tween()
	fade.tween_property(material, "albedo_color:a", 0.0, 0.4)
	fade.tween_callback(spirit.queue_free)


## Молот загорается фиолетовым огнём духа.
func _ignite() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.25, 0.5)
	material.emission_enabled = true
	material.emission = SPIRIT_COLOR
	material.emission_energy_multiplier = 2.2
	hammer_head.material_override = material
	var glow := OmniLight3D.new()
	glow.light_color = SPIRIT_COLOR
	glow.light_energy = 1.6
	glow.omni_range = 4.5
	hammer_head.add_child(glow)
	# Языки фиолетового пламени (Flame) срываются с молота и тают, отставая от взмаха.
	var flames := CPUParticles3D.new()
	var tongue := QuadMesh.new()
	tongue.size = Vector2(0.4, 0.6)
	tongue.material = Flame.material(&"spirit")
	flames.mesh = tongue
	flames.amount = 18
	flames.lifetime = 0.6
	flames.local_coords = false
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(0.45, 0.25, 0.25)
	flames.gravity = Vector3(0.0, 2.5, 0.0)
	flames.scale_amount_min = 0.7
	flames.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	flames.color_ramp = ramp
	hammer_head.add_child(flames)


# --- Выбор ударов ----------------------------------------------------------------

func _chase(delta: float) -> void:
	for blow: Blow in _cooldowns:
		_cooldowns[blow] -= delta
	if _player and not _player.is_dead():
		var dx := _player.global_position.x - global_position.x
		var distance := absf(dx)
		if phase == 2 and distance > 6.5 and _cooldowns[Blow.LEAP] <= 0.0:
			_begin([Blow.LEAP], dx)
			return
		if phase == 2 and distance > 3.5 and _cooldowns[Blow.HANDS] <= 0.0:
			_begin([Blow.HANDS], dx)
			return
		if distance > 4.0 and distance < 10.0 and _cooldowns[Blow.DRAG] <= 0.0:
			_begin([Blow.DRAG], dx)
			return
		if distance <= attack_range and _chain.is_empty():
			_chain = _close_pattern()
	super(delta)


func _begin(blows: Array[Blow], dx: float) -> void:
	_chain = blows.duplicate()
	if COOLDOWNS.has(blows[0]):
		_cooldowns[blows[0]] = COOLDOWNS[blows[0]]
	facing = signf(dx)
	_turn_t = -1.0
	_set_state(State.WINDUP)


## Вблизи — по кругу, чтобы ритм не читался заучиванием одного удара.
func _close_pattern() -> Array[Blow]:
	var patterns: Array = [[Blow.SWEEP], [Blow.SWEEP, Blow.SWEEP, Blow.SLAM_HELD], [Blow.SLAM]]
	if phase == 2:
		patterns = [[Blow.SWEEP, Blow.SLAM], [Blow.SLAM, Blow.SLAM, Blow.SLAM_BIG], [Blow.SWEEP, Blow.SWEEP, Blow.SLAM_HELD], [Blow.SLAM]]
	_pattern = (_pattern + 1) % patterns.size()
	var result: Array[Blow] = []
	result.assign(patterns[_pattern])
	return result


func _set_state(new_state: State) -> void:
	var next := new_state
	var quick := false
	if next == State.RECOVER and _chain.size() > 1:
		_chain.pop_front()
		next = State.WINDUP
		quick = true
		if _player:
			facing = signf(_player.global_position.x - global_position.x)
	if next == State.WINDUP:
		if _chain.is_empty():
			_chain = [Blow.SWEEP]
		_configure(_chain[0], quick)
	elif next == State.CHASE or next == State.OFF_BALANCE or next == State.STAGGER:
		_chain.clear()
	super(next)


func _configure(blow: Blow, quick: bool) -> void:
	_blow = blow
	var k := PHASE_SPEEDUP if phase == 2 else 1.0
	var more := _chain.size() > 1
	attack_time = 0.18
	attack_hitbox.knockback = 8.0
	match blow:
		Blow.SWEEP:
			windup_time = (0.45 if quick else sweep_windup) * k
			attack_lunge = 7.5
			recover_time = (0.3 if more else sweep_recover) * k
			attack_hitbox.damage = 22.0
		Blow.SLAM, Blow.SLAM_HELD, Blow.SLAM_BIG:
			windup_time = (0.9 if quick else slam_windup) * k
			if blow == Blow.SLAM_HELD:
				# Задержка наверху: ранний перекат уходит в пустоту.
				windup_time += 0.6
			attack_lunge = 1.5 if quick else 0.5
			recover_time = (0.4 if more else slam_stuck) * k
			attack_hitbox.damage = 40.0 if blow == Blow.SLAM_BIG else 34.0
		Blow.DRAG:
			windup_time = 0.7 * k
			attack_time = DRAG_TIME
			attack_lunge = DRAG_SPEED
			recover_time = 1.0
			attack_hitbox.damage = 20.0
			attack_hitbox.knockback = 11.0
		Blow.LEAP:
			windup_time = 0.75 * k
			attack_time = 1.6
			attack_lunge = 0.0
			recover_time = 1.2
			attack_hitbox.damage = 38.0
		Blow.HANDS:
			windup_time = 0.6
			attack_time = 0.3
			attack_lunge = 0.0
			recover_time = 1.4
			attack_hitbox.damage = 0.0


func _on_attack_started() -> void:
	match _blow:
		Blow.SLAM, Blow.SLAM_HELD, Blow.SLAM_BIG:
			_impact(_blow == Blow.SLAM_BIG or phase == 2)
		Blow.LEAP:
			velocity.y = LEAP_UP
			if _player:
				_leap_x = clampf((_player.global_position.x - global_position.x) / LEAP_AIR, -LEAP_MAX_X, LEAP_MAX_X)
		Blow.HANDS:
			attack_hitbox.active = false
			_cast_hands()
		_:
			Sfx.play(&"sword_swing", global_position, 4.0)


## Удар о камень: заметно и без попадания по герою.
func _impact(both_ways: bool) -> void:
	Events.camera_shake_requested.emit(0.75 if not both_ways else 0.95, 0.4)
	HitStop.stop(0.07)
	Sfx.play(&"sword_block", global_position, 6.0)
	var at := global_position + Vector3(facing * 2.0, 0.1, -0.3)
	HitSpark.spawn(get_parent(), at, Color(0.5, 0.48, 0.45), 40)
	_ring(at, Color(0.45, 0.4, 0.35) if phase == 1 else SPIRIT_COLOR, 3.5)
	_leave_crack(at)
	_spawn_wave(facing)
	if both_ways:
		_spawn_wave(-facing)


func _on_died() -> void:
	GameState.set_flag(boss_flag)
	_chain.clear()
	attack_hitbox.active = false
	_set_state(State.DEAD)
	Sfx.play(&"enemy_death", global_position)
	collision_layer = 0
	# Тело больше не толкают: сталкивается только с миром — долетит до земли и замрёт.
	collision_mask = 1
	hurtbox.set_deferred("monitorable", false)
	_slow_motion()
	_death_scene()


## Последний удар — время на миг замирает.
func _slow_motion() -> void:
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.7, true, false, true).timeout
	Engine.time_scale = 1.0


## Дух уходит, Кузнец опускается на колени и роняет молот — снова человек. Потом застывает
## стеклянной статуей, и только тогда с него летят отзвуки.
func _death_scene() -> void:
	for eye in eyes:
		eye.visible = false
	_spirit(false)
	_douse_hammer()
	# Из любой позы — замаха, удара, прыжка — плавно на колени: в этой позе он и застынет.
	var kneel := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	kneel.tween_property(visual, "position:y", KNEEL_Y, 1.4)
	kneel.tween_property(body_mesh, "rotation:z", KNEEL_TILT, 1.4)
	kneel.tween_property(hammer, "rotation:z", POSE_FLOOR - 0.4, 1.1)
	kneel.tween_method(func(c: Color) -> void: body_color = c, body_color, HUMAN_COLOR, STATUE_DELAY)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 0.0
	light.omni_range = 6.0
	light.position = Vector3(0.0, 2.5, 1.0)
	add_child(light)
	var glow := create_tween()
	glow.tween_property(light, "light_energy", 1.2, 2.5)
	glow.tween_property(light, "light_color", STATUE_GLOW, STATUE_TIME)
	var wait := create_tween()
	wait.tween_interval(STATUE_DELAY)
	wait.tween_callback(_turn_to_glass)


## Огонь духа на молоте гаснет.
func _douse_hammer() -> void:
	for child in hammer_head.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = false
		elif child is OmniLight3D:
			create_tween().tween_property(child, "light_energy", 0.0, 0.8)


## Тело стекленеет снизу вверх: искры инея и треск, в конце блик — статуя готова, отзвуки летят.
func _turn_to_glass() -> void:
	Sfx.play(&"glass_crack", global_position, 2.0)
	var glass := _glass_materials()
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _glaze(glass, t), 0.0, 1.0, STATUE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		statue = true
		Sfx.play(&"glass_glint", global_position, 2.0)
		HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 1.6, -0.4), STATUE_GLOW, 30))
	tween.tween_interval(STATUE_LOOT_DELAY)
	tween.tween_callback(_drop_loot)
	var frost := create_tween()
	for i in 5:
		frost.tween_interval(STATUE_TIME / 5.0)
		frost.tween_callback(func() -> void:
			HitSpark.spawn(get_parent(), global_position + Vector3(randf_range(-0.8, 0.8), lerpf(0.2, 2.6, i / 4.0), -0.4), STATUE_COLOR, 10))


## Своя копия материала у каждой части тела: [материал, цвет до стекла, шероховатость до стекла].
func _glass_materials() -> Array:
	var result := []
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh in eyes:
			continue
		var base := mesh.material_override as StandardMaterial3D
		if base == null and mesh.mesh:
			base = mesh.mesh.surface_get_material(0) as StandardMaterial3D
		var glass := base.duplicate() as StandardMaterial3D if base else StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		glass.emission_enabled = true
		glass.rim_enabled = true
		mesh.material_override = glass
		result.append([glass, glass.albedo_color, glass.roughness, glass.emission, glass.emission_energy_multiplier])
	return result


func _glaze(glass: Array, t: float) -> void:
	for part: Array in glass:
		var material: StandardMaterial3D = part[0]
		material.albedo_color = (part[1] as Color).lerp(STATUE_COLOR, t)
		material.roughness = lerpf(part[2], 0.06, t)
		material.metallic = 0.4 * t
		material.rim = t
		material.emission = (part[3] as Color).lerp(STATUE_GLOW, t)
		material.emission_energy_multiplier = lerpf(part[4], 0.35, t)


## Статуя готова: отзвуки летят к герою, мастерство засчитано, у статуи появляется отзвук босса.
func _drop_loot() -> void:
	_place_loot()
	GameState.set_flag(loot_flag)
	Events.enemy_killed.emit(self)


## Отзвук босса — перед статуей, в плоскости героя, со стороны, куда она смотрит: статую
## можно пройти насквозь, но поднимать лут удобнее перед ней.
func _place_loot() -> void:
	for node in get_parent().get_children():
		var pickup := node as ItemPickup
		if pickup and pickup.appear_flag == loot_flag:
			pickup.global_position = Vector3(global_position.x + facing * LOOT_AHEAD, global_position.y, 0.0)


## Побеждён раньше: на его месте стоит на коленях стеклянная статуя.
func _stand_as_statue() -> void:
	state = State.DEAD
	statue = true
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 1
	hurtbox.set_deferred("monitorable", false)
	for eye in eyes:
		eye.visible = false
	visual.position.y = KNEEL_Y
	body_mesh.rotation.z = KNEEL_TILT
	hammer.rotation.z = POSE_FLOOR - 0.4
	hammer.position.z = 0.75 * facing
	body_color = HUMAN_COLOR
	_material.albedo_color = HUMAN_COLOR
	_material.emission = Color.BLACK
	_glaze(_glass_materials(), 1.0)
	set_physics_process(false)
	# Ушёл из комнаты, пока стекленел: отзвуки — сейчас.
	if not GameState.has_flag(loot_flag):
		_drop_loot.call_deferred()
	else:
		_place_loot.call_deferred()


func _on_hurt(hitbox: Hitbox) -> void:
	if _scene_running or state == State.DORMANT:
		return
	super(hitbox)
	if state == State.DEAD or health.is_dead():
		return
	# Сбитая стойкость: Кузнец на колене — время добить.
	if state == State.STAGGER:
		_set_state(State.OFF_BALANCE)
	if phase == 1 and health.current <= health.max_health * PHASE_AT:
		_transition()


# --- Приёмы ----------------------------------------------------------------------

## Руки духа: под героем светится круг, потом из земли бьют когти. Дважды подряд.
func _cast_hands() -> void:
	for i in 2:
		if _player == null or state == State.DEAD:
			return
		_spawn_hand(_player.global_position.x)
		await get_tree().create_timer(0.55).timeout


func _spawn_hand(x: float) -> void:
	var hand := Node3D.new()
	get_parent().add_child(hand)
	hand.global_position = Vector3(x, global_position.y, 0.0)
	var mark_material := StandardMaterial3D.new()
	mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark_material.albedo_color = Color(SPIRIT_COLOR, 0.0)
	var mark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	disc.material = mark_material
	mark.mesh = disc
	mark.position.y = 0.05
	hand.add_child(mark)
	var warn := hand.create_tween()
	warn.tween_property(mark_material, "albedo_color:a", 0.7, HAND_WARN).set_trans(Tween.TRANS_SINE)
	await warn.finished
	if not is_instance_valid(hand):
		return
	var claw_material := StandardMaterial3D.new()
	claw_material.albedo_color = Color(0.2, 0.12, 0.3)
	claw_material.emission_enabled = true
	claw_material.emission = SPIRIT_COLOR
	claw_material.emission_energy_multiplier = 1.5
	for i in 3:
		var claw := MeshInstance3D.new()
		var spike := BoxMesh.new()
		spike.size = Vector3(0.18, 1.8, 0.18)
		spike.material = claw_material
		claw.mesh = spike
		claw.position = Vector3((i - 1) * 0.35, -1.0, 0.0)
		claw.rotation.z = (i - 1) * -0.3
		hand.add_child(claw)
		hand.create_tween().tween_property(claw, "position:y", 0.9, 0.12)
	var hit := Hitbox.new()
	hit.collision_layer = 0
	hit.collision_mask = 1 << 1
	hit.damage = HAND_DAMAGE
	hit.knockback = 6.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.2, 3.0)
	shape.shape = box
	shape.position.y = 1.1
	hit.add_child(shape)
	hand.add_child(hit)
	hit.active = true
	HitSpark.spawn(get_parent(), hand.global_position + Vector3(0.0, 0.6, 0.0), SPIRIT_COLOR, 20)
	Events.camera_shake_requested.emit(0.25, 0.2)
	var after := hand.create_tween()
	after.tween_interval(0.25)
	after.tween_callback(func() -> void: hit.active = false)
	after.tween_property(mark_material, "albedo_color:a", 0.0, 0.4)
	after.tween_callback(hand.queue_free)


## Кольцо пыли (или духа) от удара: растёт и гаснет.
func _ring(at: Vector3, color: Color, radius: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.6)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.material = material
	ring.mesh = torus
	get_parent().add_child(ring)
	ring.global_position = at
	ring.scale = Vector3(0.3, 0.3, 0.3)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)


## Короткий удар кольцом вокруг (переход фазы): отбрасывает героя.
func _burst_hitbox(size: Vector3, damage: float, knockback: float) -> void:
	var hit := Hitbox.new()
	hit.collision_layer = 0
	hit.collision_mask = 1 << 1
	hit.damage = damage
	hit.knockback = knockback
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	hit.add_child(shape)
	get_parent().add_child(hit)
	hit.global_position = global_position
	hit.active = true
	var tween := hit.create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(hit.queue_free)


## Трещина в камне остаётся до перезагрузки комнаты.
func _leave_crack(at: Vector3) -> void:
	var crack := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(2.6, 0.03, 1.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02)
	plate.material = mat
	crack.mesh = plate
	get_parent().add_child(crack)
	crack.global_position = Vector3(at.x, global_position.y + 0.02, -0.4)
	crack.rotation.y = randf_range(-0.4, 0.4)


## Волна по полу: через неё перепрыгивают.
func _spawn_wave(dir: float) -> void:
	var wave := Hitbox.new()
	wave.collision_layer = 0
	wave.collision_mask = 2
	wave.damage = WAVE_DAMAGE
	wave.knockback = 5.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.7, 1.2)
	shape.shape = box
	shape.position.y = 0.35
	wave.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.9, 0.5, 1.0)
	var mat := StandardMaterial3D.new()
	var color := Color(1.0, 0.45, 0.15) if phase == 1 else SPIRIT_COLOR
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	cube.material = mat
	mesh.mesh = cube
	mesh.position.y = 0.25
	wave.add_child(mesh)
	get_parent().add_child(wave)
	wave.global_position = Vector3(global_position.x + dir * 1.8, global_position.y, 0.0)
	wave.active = true
	var tween := wave.create_tween()
	tween.tween_property(wave, "global_position:x", wave.global_position.x + dir * WAVE_SPEED * WAVE_TIME, WAVE_TIME)
	tween.tween_callback(wave.queue_free)


## Призрачный след за головой молота в ударе.
func _afterimage() -> void:
	var copy := MeshInstance3D.new()
	copy.mesh = hammer_head.mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(SPIRIT_COLOR if phase == 2 else Color(0.8, 0.75, 0.7), 0.35)
	copy.material_override = material
	get_parent().add_child(copy)
	copy.global_transform = hammer_head.global_transform
	var tween := copy.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(copy.queue_free)


# --- Каждый кадр -----------------------------------------------------------------

func _update_extra(delta: float) -> void:
	if not seated and not _engaged and _player and state != State.DORMANT and _sees_player(detect_range, false):
		_engaged = true
		Events.boss_engaged.emit(self)
	if state == State.ATTACK:
		match _blow:
			Blow.DRAG:
				velocity.x = facing * DRAG_SPEED
				_spark_t -= delta
				if _spark_t <= 0.0:
					_spark_t = 0.05
					HitSpark.spawn(get_parent(), hammer_head.global_position, Color(1.0, 0.65, 0.25), 6)
			Blow.LEAP:
				velocity.x = _leap_x
				if is_on_floor() and _state_time > 0.2:
					_impact(true)
					_set_state(State.RECOVER)
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			_afterimage()
	# Модель стоит глубже героя (Visual в сцене), молот — между ними, куда бы босс ни смотрел.
	hammer.position.z = 0.75 * facing
	if _scene_running or state == State.DORMANT or state == State.DEAD:
		return
	var down := POSE_FLOOR if _blow in [Blow.SLAM, Blow.SLAM_HELD, Blow.SLAM_BIG, Blow.LEAP] else POSE_SWEPT
	var pose := POSE_DRAG
	var speed := 5.0
	match state:
		State.WINDUP:
			# Тяжело поднимает и держит наверху.
			match _blow:
				Blow.SWEEP: pose = POSE_BACK
				Blow.DRAG: pose = POSE_DRAG
				_: pose = POSE_OVERHEAD
			speed = 3.0
		State.ATTACK:
			pose = POSE_DRAG if _blow == Blow.DRAG else (POSE_OVERHEAD if _blow in [Blow.LEAP, Blow.HANDS] else down)
			speed = 40.0
		State.RECOVER:
			# Молот лежит, где упал, потом его с трудом вытаскивают.
			pose = down if _state_time < recover_time * 0.6 else POSE_DRAG
			speed = 3.0
		State.OFF_BALANCE:
			pose = POSE_FLOOR
			speed = 6.0
		State.BLINDED:
			# Отпустил молот: тот встал навершием в землю.
			pose = POSE_FLOOR
			speed = 4.0
	hammer.rotation.z = lerpf(hammer.rotation.z, pose, 1.0 - exp(-speed * delta))
