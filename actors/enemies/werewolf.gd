class_name Werewolf
extends Dummy
## Оборотень на площади: конец первой сцены игры (§9.2). Мальчишке с палкой его не одолеть:
## удары не смертельны, а чем кончается бой, решает SquareEvent. Вблизи рвёт когтями двойным ударом,
## издали то бросается рывком, то прыгает на героя сверху. Быстрый хищник: разворот почти мгновенный.

const FAR_RANGE := 4.5
const FAR_COOLDOWN := 2.2
const LEAP_UP := 11.0
const LEAP_AIR_TIME := 0.73
const LEAP_MAX_X := 14.0
const ROAR_TIME := 0.9
## Уходит в лес: и вбок, и в глубину кадра.
const FLEE_VELOCITY := Vector3(8.0, 0.0, -9.0)
const FLEE_TIME := 2.0

enum Move { CLAW, RUSH, LEAP }

@export var boss_name := "Оборотень"
## Поставлен — зверь уже ушёл из этой комнаты навсегда.
@export var gone_flag: StringName = &"fire_out"
## Склонился над жертвой, пока герой не подойдёт на это расстояние.
@export var wake_range := 9.0

var move := Move.CLAW
var engaged := false
var _far_wait := 1.0
var _next_far := Move.LEAP
var _second_claw := false
var _leap_x := 0.0
var _roar := 0.0
var _called := false
var _fleeing := false
var _flee_t := 0.0

@onready var arm_front: Node3D = $Visual/ArmFront
@onready var arm_back: Node3D = $Visual/ArmBack
@onready var head: Node3D = $Visual/Head


func _ready() -> void:
	super()
	if GameState.has_flag(gone_flag):
		queue_free()


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


## Выбор удара: вблизи когти, издали рывок и прыжок по очереди.
func _chase(delta: float) -> void:
	_far_wait -= delta
	if _player and not _player.is_dead():
		var dx := _player.global_position.x - global_position.x
		if absf(dx) > FAR_RANGE and _far_wait <= 0.0:
			facing = signf(dx)
			_turn_t = -1.0
			move = _next_far
			_next_far = Move.RUSH if move == Move.LEAP else Move.LEAP
			_far_wait = FAR_COOLDOWN
			_set_state(State.WINDUP)
			return
	move = Move.CLAW
	_second_claw = false
	super(delta)


func _set_state(new_state: State) -> void:
	# Когти бьют дважды: вместо передышки — сразу второй замах.
	var next := new_state
	var quick := false
	if next == State.RECOVER and move == Move.CLAW and not _second_claw:
		_second_claw = true
		quick = true
		next = State.WINDUP
		if _player:
			facing = signf(_player.global_position.x - global_position.x)
	if next == State.WINDUP:
		_prepare(quick)
	super(next)


func _prepare(quick: bool) -> void:
	match move:
		Move.CLAW:
			windup_time = 0.2 if quick else 0.42
			attack_time = 0.16
			attack_lunge = 7.0
			recover_time = 0.6
			attack_hitbox.damage = 18.0
		Move.RUSH:
			windup_time = 0.6
			attack_time = 0.5
			attack_lunge = 15.0
			recover_time = 0.7
			attack_hitbox.damage = 28.0
		Move.LEAP:
			windup_time = 0.65
			attack_time = 1.4
			attack_lunge = 0.0
			recover_time = 0.7
			attack_hitbox.damage = 32.0


func _on_attack_started() -> void:
	Sfx.play(&"sword_swing", global_position, 2.0)
	if move == Move.LEAP and _player:
		velocity.y = LEAP_UP
		_leap_x = clampf((_player.global_position.x - global_position.x) / LEAP_AIR_TIME, -LEAP_MAX_X, LEAP_MAX_X)


func _land() -> void:
	Events.camera_shake_requested.emit(0.5, 0.3)
	HitStop.stop(0.05)
	Sfx.play(&"sword_block", global_position, 3.0)
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 0.1, -0.3), Color(0.35, 0.3, 0.26), 24)
	_set_state(State.RECOVER)


## До боя склонился над жертвой; услышал героя — рычит и бросается. После зова уходит.
func _wake_check(delta: float) -> void:
	if _called:
		_after_call(delta)
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
	match state:
		State.WINDUP:
			arm = -2.4 if move == Move.CLAW else -1.0
			crouch = 1.0 if move == Move.CLAW else 0.72
		State.ATTACK:
			arm = 1.3
			crouch = 0.8 if move == Move.RUSH else 1.0
			speed = 30.0
		State.RECOVER:
			arm = 0.5
			crouch = 0.9
	var k := 1.0 - exp(-speed * delta)
	arm_front.rotation.z = lerpf(arm_front.rotation.z, arm, k)
	arm_back.rotation.z = lerpf(arm_back.rotation.z, arm * 0.6, k)
	visual.scale.y = lerpf(visual.scale.y, crouch, k)
	head.rotation.z = lerpf(head.rotation.z, 0.0, 1.0 - exp(-6.0 * delta))
