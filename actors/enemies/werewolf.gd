class_name Werewolf
extends Dummy
## Оборотень на площади: конец первой сцены игры (§9.2). Мальчишке с палкой его не одолеть:
## удары не смертельны, а чем кончается бой, решает SquareEvent. Быстрый хищник: разворот почти
## мгновенный, давит без передышки.
## - Когти: три удара, третий с задержкой — ловит ранний перекат.
## - Рывок издали и прыжок сверху; прыжок, попав, прижимает героя к земле и рвёт.
## - Обман: отскок назад и сразу рывок.
## - Рёв вплотную: отбрасывает героя, если тот прилип и бьёт.

const FAR_RANGE := 4.5
const FAR_COOLDOWN := 2.0
const LEAP_UP := 11.0
const LEAP_AIR_TIME := 0.73
const LEAP_MAX_X := 14.0
const ROAR_TIME := 0.9
const PIN_TIME := 1.1
const PIN_BITES := 2
const PIN_BITE := 8.0
## Сколько ударов героя подряд вплотную — и зверь ревёт.
const ROAR_AFTER_HITS := 3
const ROAR_PUSH := 11.0
const FEINT_SPEED := 9.0
## Уходит в лес: и вбок, и в глубину кадра.
const FLEE_VELOCITY := Vector3(8.0, 0.0, -9.0)
const FLEE_TIME := 2.0

enum Move { CLAW, RUSH, LEAP, FEINT, HOWL }

@export var boss_name := "Оборотень"
## Поставлен — зверь уже ушёл из этой комнаты навсегда.
@export var gone_flag: StringName = &"fire_out"
## Склонился над жертвой, пока герой не подойдёт на это расстояние.
@export var wake_range := 9.0

var move := Move.CLAW
var engaged := false
var _far_wait := 1.0
var _next_far := Move.LEAP
var _claws := 0
var _leap_x := 0.0
var _roar := 0.0
var _called := false
var _fleeing := false
var _flee_t := 0.0
var _hits_taken := 0
var _feint_wait := 3.0

@onready var arm_front: Node3D = $Visual/ArmFront
@onready var arm_back: Node3D = $Visual/ArmBack
@onready var head: Node3D = $Visual/Head


func _ready() -> void:
	super()
	if GameState.has_flag(gone_flag):
		queue_free()
		return
	attack_hitbox.hit_landed.connect(_on_hit_hero)


## Услышал зов: бой окончен, зверь замирает и поднимает морду.
func heed_call() -> void:
	_called = true
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	_set_state(State.DORMANT)


func flee() -> void:
	_fleeing = true
	facing = 1.0 if global_position.x < 0.0 else -1.0
	visual.rotation.y = 0.0 if facing > 0.0 else PI


## Выбор приёма: рёв, если герой прилип; издали рывок и прыжок; иногда обман; вблизи когти.
func _chase(delta: float) -> void:
	_far_wait -= delta
	_feint_wait -= delta
	if _player and not _player.is_dead():
		var dx := _player.global_position.x - global_position.x
		if _hits_taken >= ROAR_AFTER_HITS and absf(dx) < 3.0:
			_start(Move.HOWL, dx)
			return
		if absf(dx) > FAR_RANGE and _far_wait <= 0.0:
			_start(_next_far, dx)
			_next_far = Move.RUSH if _next_far == Move.LEAP else Move.LEAP
			_far_wait = FAR_COOLDOWN
			return
		if absf(dx) < 2.6 and _feint_wait <= 0.0 and randf() < 0.35:
			_feint_wait = 5.0
			_start(Move.FEINT, dx)
			return
	move = Move.CLAW
	_claws = 0
	super(delta)


func _start(next: Move, dx: float) -> void:
	move = next
	facing = signf(dx)
	_turn_t = -1.0
	_set_state(State.WINDUP)


func _set_state(new_state: State) -> void:
	var next := new_state
	var follow := false
	# Когти: три удара подряд, вместо передышки — следующий замах.
	if next == State.RECOVER and move == Move.CLAW and _claws < 2:
		_claws += 1
		follow = true
		next = State.WINDUP
		if _player:
			facing = signf(_player.global_position.x - global_position.x)
	# Обман: отскочил — и сразу рывок.
	if next == State.RECOVER and move == Move.FEINT:
		move = Move.RUSH
		next = State.WINDUP
		follow = true
	if next == State.WINDUP:
		_prepare(follow)
	super(next)


func _prepare(follow: bool) -> void:
	attack_hitbox.knockback = 7.0
	match move:
		Move.CLAW:
			# Третий удар с задержкой наверху.
			windup_time = 0.42 if not follow else (0.2 if _claws < 2 else 0.62)
			attack_time = 0.16
			attack_lunge = 7.0
			recover_time = 0.6
			attack_hitbox.damage = 16.0 if _claws < 2 else 22.0
		Move.RUSH:
			windup_time = 0.25 if follow else 0.6
			attack_time = 0.5
			attack_lunge = 15.0
			recover_time = 0.7
			attack_hitbox.damage = 26.0
		Move.LEAP:
			windup_time = 0.65
			attack_time = 1.4
			attack_lunge = 0.0
			recover_time = 0.7
			attack_hitbox.damage = 28.0
		Move.FEINT:
			windup_time = 0.15
			attack_time = 0.3
			attack_lunge = -FEINT_SPEED
			recover_time = 0.1
			attack_hitbox.damage = 0.0
		Move.HOWL:
			windup_time = 0.5
			attack_time = 0.3
			attack_lunge = 0.0
			recover_time = 0.6
			attack_hitbox.damage = 6.0
			attack_hitbox.knockback = ROAR_PUSH


func _on_attack_started() -> void:
	match move:
		Move.LEAP:
			Sfx.play(&"sword_swing", global_position, 2.0)
			if _player:
				velocity.y = LEAP_UP
				_leap_x = clampf((_player.global_position.x - global_position.x) / LEAP_AIR_TIME, -LEAP_MAX_X, LEAP_MAX_X)
		Move.FEINT:
			attack_hitbox.active = false
			velocity.y = 4.0
		Move.HOWL:
			_hits_taken = 0
			Events.camera_shake_requested.emit(0.45, 0.5)
			Sfx.play_ui(&"distant_howl", -10.0)
		_:
			Sfx.play(&"sword_swing", global_position, 2.0)


## Прыжок попал: зверь прижимает героя к земле и рвёт, потом отбрасывает.
func _on_hit_hero(_hurtbox: Hurtbox) -> void:
	if move != Move.LEAP or _player == null or _player.is_dead() or _player.health.current <= 1.0:
		return
	_pin()


func _pin() -> void:
	var hero := _player
	hero.knock_down()
	_set_state(State.DORMANT)
	for i in PIN_BITES:
		await get_tree().create_timer(PIN_TIME / (PIN_BITES + 1)).timeout
		if not is_instance_valid(hero) or _called:
			return
		hero.health.take_damage(PIN_BITE, true)
		hero.body.flash(Color(1.0, 0.25, 0.2))
		Events.camera_shake_requested.emit(0.25, 0.15)
	await get_tree().create_timer(PIN_TIME / (PIN_BITES + 1)).timeout
	if _called or not is_instance_valid(hero):
		return
	hero.stand_up()
	hero.velocity = Vector3(facing * 9.0, 4.0, 0.0)
	_set_state(State.RECOVER)


func _on_hurt(hitbox: Hitbox) -> void:
	super(hitbox)
	if _player and absf(_player.global_position.x - global_position.x) < 3.0:
		_hits_taken += 1


func _land() -> void:
	Events.camera_shake_requested.emit(0.5, 0.3)
	HitStop.stop(0.05)
	Sfx.play(&"sword_block", global_position, 3.0)
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 0.1, -0.3), Color(0.35, 0.3, 0.26), 24)
	if state == State.ATTACK:
		_set_state(State.RECOVER)


## До боя склонился над жертвой; услышал героя — рычит и бросается. После зова уходит.
func _wake_check(delta: float) -> void:
	if _called:
		_after_call(delta)
		return
	if engaged and _roar >= ROAR_TIME:
		# Прижал героя к земле: стоит над ним.
		velocity = Vector3.ZERO
		return
	_find_player()
	if _player == null:
		return
	var dx := _player.global_position.x - global_position.x
	if _roar == 0.0 and absf(dx) >= wake_range:
		return
	if _roar == 0.0:
		facing = signf(dx)
		visual.rotation.y = 0.0 if facing > 0.0 else PI
		engaged = true
		Events.boss_engaged.emit(self)
		Events.camera_shake_requested.emit(0.3, 0.5)
		Sfx.play_ui(&"heartbeat")
	_roar += delta
	head.rotation.z = lerpf(head.rotation.z, 0.6, 1.0 - exp(-8.0 * delta))
	if _roar >= ROAR_TIME:
		_set_state(State.CHASE)


func _after_call(delta: float) -> void:
	head.rotation.z = lerpf(head.rotation.z, 0.9, 1.0 - exp(-5.0 * delta))
	if not _fleeing:
		if not is_on_floor():
			velocity.y -= gravity * delta
			velocity.x = 0.0
			move_and_slide()
		return
	_flee_t += delta
	global_position += Vector3(FLEE_VELOCITY.x * facing, 0.0, FLEE_VELOCITY.z) * delta
	if _flee_t >= FLEE_TIME:
		queue_free()


func _update_extra(delta: float) -> void:
	if state == State.ATTACK and move == Move.LEAP:
		velocity.x = _leap_x
		if is_on_floor() and _state_time > 0.2:
			_land()
	var arm := 0.2
	var crouch := 1.0
	var speed := 8.0
	var howl := 0.0
	match state:
		State.WINDUP:
			arm = -2.4 if move == Move.CLAW else -1.0
			crouch = 1.0 if move in [Move.CLAW, Move.HOWL] else 0.72
			howl = 0.5 if move == Move.HOWL else 0.0
		State.ATTACK:
			arm = 1.3
			crouch = 0.8 if move == Move.RUSH else 1.0
			howl = 0.9 if move == Move.HOWL else 0.0
			speed = 30.0
		State.RECOVER:
			arm = 0.5
			crouch = 0.9
	var k := 1.0 - exp(-speed * delta)
	arm_front.rotation.z = lerpf(arm_front.rotation.z, arm, k)
	arm_back.rotation.z = lerpf(arm_back.rotation.z, arm * 0.6, k)
	visual.scale.y = lerpf(visual.scale.y, crouch, k)
	head.rotation.z = lerpf(head.rotation.z, howl, 1.0 - exp(-6.0 * delta))
