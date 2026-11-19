class_name Poludnitsa
extends Dummy
## Полудница (§8.13 Поля, §8.14 «волна во ржи»): дух полудня в ржи, враг средней сложности. Прячется под
## колосьями — её не видно и не ударить; выдаёт её только волна: где она идёт, рожь клонится против ветра
## и дрожит. Подбирается к герою сзади, встаёт из ржи с серпом и бьёт серией из трёх: два быстрых взмаха и
## тяжёлый последний, с задержкой — ловит ранний перекат. После серии уходит обратно в рожь (пока уходит —
## окно для удара) и всплывает в другом месте. Вне ржи прятаться негде: открыта, медленнее, и в рожь уходит,
## только когда туда войдёт герой. Слышит далеко — её зовут вороны на жнивье (CrowFlock).
## Класс — дух: святая вода бьёт её сильно (unholy). Графика — graybox: белая рубаха, солома волос, серп.

enum Phase { HIDDEN, RISING, OUT, SINKING }

## Насколько она под землёй, пока прячется.
const SUNK := -2.3
const RISE_TIME := 0.5
const SINK_TIME := 0.6
## Скорость под колосьями: быстрее, чем на открытом месте.
const STALK_SPEED := 3.8
## Встаёт, подобравшись к герою на это расстояние — за спиной.
const SURFACE_RANGE := 1.3
## После ухода в рожь столько ищет новое место, держась поодаль.
const REPOSITION_TIME := 1.8
const KEEP_AWAY := 5.0
## Взмахов в серии.
const COMBO := 3
const STRAW := Color(0.78, 0.68, 0.38)

var phase := Phase.HIDDEN
## Сколько взмахов серии уже было (0 — первый).
var combo_step := 0
## Сила волны в ржи сейчас (для тестов и снимков).
var rustle := 0.0

var _fields: Array[RyeField] = []
var _cooldown := 0.0
var _hunting := false
var _heard_x := NAN
var _rustle_sound := 0.0


func _init() -> void:
	creature = CreatureKind.Kind.SPIRIT
	graybox_arms = false


func _ready() -> void:
	super()
	Events.noise_made.connect(_on_far_noise)
	if dormant and in_rye(global_position):
		_hide_now()
	else:
		phase = Phase.OUT
		if state == State.DORMANT:
			dormant = false
			_set_state(State.PATROL)


## Внутри ли полосы ржи точка на земле.
func in_rye(point: Vector3) -> bool:
	for field in _rye_fields():
		if is_instance_valid(field) and field.covers(point):
			return true
	return false


## Пока прячется: идёт под колосьями к герою (за спину) или к шуму, поднимается рядом с ним.
func _wake_check(delta: float) -> void:
	if phase != Phase.HIDDEN:
		return
	_find_player()
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target_x := global_position.x
	var hero_in_rye := false
	if _player and not _player.is_dead() and absf(_player.global_position.y - global_position.y) < 3.0:
		var dx_hero := _player.global_position.x - global_position.x
		hero_in_rye = in_rye(_player.global_position)
		if absf(dx_hero) < detect_range:
			_hunting = true
		if _hunting:
			if _cooldown > 0.0:
				# Ушла в рожь — держится поодаль, выбирает, откуда встать.
				target_x = _player.global_position.x + signf(global_position.x - _player.global_position.x + 0.01) * KEEP_AWAY
			else:
				target_x = _player.global_position.x - _player.facing * SURFACE_RANGE
	if not _hunting and not is_nan(_heard_x):
		target_x = _heard_x
	target_x = _clamp_to_rye(target_x)
	var dx := target_x - global_position.x
	# Под колосьями она дух, не тело: не цепляется за кочки и края увалов — идёт по земле, держась её высоты.
	var step := signf(dx) * minf(STALK_SPEED * delta, absf(dx)) if absf(dx) > 0.05 else 0.0
	velocity.x = step / maxf(delta, 0.001)
	global_position.x += step
	var ground := _ground_below()
	if not is_nan(ground):
		global_position.y = ground
	var moving := absf(velocity.x) > 0.3
	rustle = move_toward(rustle, 1.0 if moving else 0.35, delta * 3.0)
	_disturb(rustle)
	_rustle_sound -= delta
	if moving and _rustle_sound <= 0.0:
		_rustle_sound = 0.45
		Sfx.play(&"rye_rustle", global_position + Vector3(0.0, 0.8, 0.0), -6.0)
	if not _hunting or _cooldown > 0.0 or _player == null or _player.is_dead():
		return
	var gap := absf(_player.global_position.x - global_position.x)
	# Герой во ржи — встаёт за его спиной; герой вне ржи, но у края — встаёт на краю и выходит к нему.
	if (hero_in_rye and gap <= SURFACE_RANGE + 0.35) or (not hero_in_rye and gap <= 3.0):
		_rise()


## Встаёт из ржи: колосья разлетаются, белая фигура поднимается — и сразу замах, если герой рядом.
func _rise() -> void:
	phase = Phase.RISING
	velocity = Vector3.ZERO
	facing = signf(_player.global_position.x - global_position.x) if _player else facing
	visual.rotation.y = 0.0 if facing > 0.0 else PI
	visual.visible = true
	collision_layer = 4
	collision_mask = 3
	hurtbox.monitorable = true
	_disturb(1.0)
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 0.9, 0.3), STRAW, 26)
	Sfx.play(&"poludnitsa_rise", global_position + Vector3(0.0, 1.2, 0.0))
	var tween := create_tween()
	tween.tween_property(visual, "position:y", 0.0, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if state == State.DEAD:
		return
	phase = Phase.OUT
	combo_step = 0
	dormant = false
	_disturb(0.0)
	if _player and absf(_player.global_position.x - global_position.x) <= attack_range + 0.6:
		_set_state(State.WINDUP)
	else:
		_set_state(State.CHASE)


## Уходит в рожь: пока опускается — её можно ударить; потом прячется и ищет новое место.
func _sink() -> void:
	phase = Phase.SINKING
	recover_time = SINK_TIME + 0.2
	super._set_state(State.RECOVER)
	Sfx.play(&"rye_rustle", global_position + Vector3(0.0, 0.8, 0.0))
	var tween := create_tween()
	tween.tween_property(visual, "position:y", SUNK, SINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if state == State.DEAD or phase != Phase.SINKING:
		return
	_hide_now()
	_cooldown = REPOSITION_TIME


func _hide_now() -> void:
	phase = Phase.HIDDEN
	visual.position.y = SUNK
	visual.visible = false
	hurtbox.monitorable = false
	collision_layer = 0
	collision_mask = 0
	attack_hitbox.active = false
	combo_step = 0
	super._set_state(State.DORMANT)


## Серия из трёх: два быстрых взмаха серпом и тяжёлый последний с задержкой. Во ржи после серии — уходит.
func _set_state(new_state: State) -> void:
	var next := new_state
	if phase == Phase.SINKING and next in [State.CHASE, State.PATROL, State.INVESTIGATE]:
		return
	if phase == Phase.OUT and next == State.RECOVER and state == State.ATTACK and combo_step < COMBO - 1:
		combo_step += 1
		next = State.WINDUP
	if next == State.WINDUP:
		var last := combo_step == COMBO - 1
		windup_time = 0.5 if combo_step == 0 else (0.62 if last else 0.22)
		attack_hitbox.damage = 22.0 if last else 12.0
		attack_hitbox.knockback = 8.0 if last else 3.5
		attack_hitbox.heavy = last
		attack_lunge = 6.0 if last else 3.0
		recover_time = 0.7 if last else 0.3
	if next in [State.CHASE, State.PATROL] and phase == Phase.OUT and in_rye(global_position) \
			and (_player == null or in_rye(_player.global_position)):
		_sink()
		return
	super(next)


## Вне ржи — медленно идёт к герою; вошёл в рожь — уходит под колосья.
func _chase(delta: float) -> void:
	if phase == Phase.OUT and in_rye(global_position) and _player and in_rye(_player.global_position):
		_sink()
		return
	super(delta)


## Шум (вороны взлетели, стрела воткнулась) слышен далеко: под колосьями идёт к нему.
func _on_far_noise(at: Vector3, radius: float) -> void:
	if phase != Phase.HIDDEN or not is_inside_tree():
		return
	if global_position.distance_to(at) <= minf(radius, hearing_range):
		_heard_x = at.x


func _clamp_to_rye(x: float) -> float:
	var best := x
	var best_gap := INF
	for field in _rye_fields():
		if not is_instance_valid(field):
			continue
		var half := field.length * 0.5
		var lo := field.global_position.x - half + 0.4
		var hi := field.global_position.x + half - 0.4
		# Только та полоса, где она сейчас: из одной ржи в другую под землёй не ходит.
		if global_position.x < lo - 0.6 or global_position.x > hi + 0.6:
			continue
		var clamped := clampf(x, lo, hi)
		if absf(clamped - x) < best_gap:
			best_gap = absf(clamped - x)
			best = clamped
	return best


## Высота земли под ней (мир) или NAN.
func _ground_below() -> float:
	var from := global_position + Vector3(0.0, 2.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -6.0, 0.0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else (hit.position as Vector3).y


## Полосы ржи комнаты (группа rye_field); собираются при первом обращении — рожь могла встать позже.
func _rye_fields() -> Array[RyeField]:
	if _fields.is_empty() and is_inside_tree():
		for node in get_tree().get_nodes_in_group(&"rye_field"):
			if node is RyeField:
				_fields.append(node as RyeField)
	return _fields


func _disturb(strength: float) -> void:
	for field in _rye_fields():
		if is_instance_valid(field):
			field.disturb(global_position, strength if field.covers(global_position) else 0.0)


func _on_died() -> void:
	_disturb(0.0)
	super()
