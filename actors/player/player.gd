class_name Player
extends CharacterBody3D
## Герой: движение в плоскости XY, перекат, меч, удар вниз, скольжение и лазание по стеклу,
## блок и парирование, добивание и удар в спину, лук.
## Все числа скорости и урона берутся из PlayerStats, который зависит от возраста (§1.3).

signal died
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal attack_step_started(step: AttackStep, index: int, total: int)
signal arrow_fired(arrow: Arrow)

enum State {
	MOVE, ROLL, ATTACK, PLUNGE, SLIDE, CLIMB, HURT, DEAD, BLOCK, GUARD_BROKEN, CRITICAL, BOW,
	LEDGE_HANG, LEDGE_CLIMB,
}

const KILL_Y := -15.0
const PLUNGE_LAND_TIME := 0.15
const HURT_TIME := 0.3
const SLIDE_LEAN := 0.35
## С какой скоростью герой соскальзывает с головы врага: на врагах не стоят.
const HEAD_SLIDE_SPEED := 5.0
## На каком расстоянии герой встаёт к врагу для добивания и удара в спину.
const CRITICAL_DISTANCE := 1.0

@export var stats: PlayerStats
## Оружие и его набор атак (§6.2).
@export var weapon: WeaponData

var state := State.MOVE
var facing := 1.0
var stamina := 0.0
## Пока true — игрок не управляется (переход через зеркало, затемнение).
var frozen := false
## Позы меча и лук.
var arms: PlayerArms
## Капсула: вспышки и поза смерти.
var body: PlayerBody

var _state_time := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _attack_buffer := 0.0
var _roll_buffer := 0.0
var _iframes := 0.0
var _stamina_delay := 0.0
var _input_lock := 0.0
var _combo := 0
var _step: AttackStep
var _fast_attack := false
var _roll_dir := 1.0
var _roll_speed := 0.0
var _plunge_landed_at := -1.0
## Окно парирования: сколько ещё секунд после нажатия блока удар будет парирован.
var _parry_t := 0.0
## Сколько секунд прошло после выхода из скольжения и после кувырка (для особых ударов).
var _since_slide := 99.0
var _since_roll := 99.0
var _roll_attack_queued := false
var _critical_target: Dummy
var _critical_done := false
var _critical_pierced := false
var _critical_holding := false
var _death_landed := false
var _death_dir := 1.0
var _shoot_buffer := 0.0
## Натяжение лука 0…1.
var _draw_t := 0.0
## Колышек-стрела, которого сейчас касается герой.
var _peg: ArrowPeg
var _floor_glass_normal := Vector3.ZERO
var _floor_glass: GlassSurface
## Стоим на голове врага: направление, куда соскальзываем (0 — не стоим).
var _head_slide := 0.0
## Скорость вдоль ската. Храним сами: move_and_slide() на склоне срезает вертикаль у velocity.
var _slide_speed := 0.0
var _slide_dir := Vector3.RIGHT
var _reach := PlayerReach.new()
var _foley := PlayerFoley.new()
var _sword_shape: BoxShape3D
## Уступ: в какую сторону край, точка виса и точка, куда встаём.
var _ledge_dir := 1.0
var _ledge_hang := Vector3.ZERO
var _ledge_stand := Vector3.ZERO
var _ledge_cooldown := 0.0

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var sword_pivot: Node3D = $Visual/SwordPivot
@onready var sword_hitbox: Hitbox = $Visual/SwordHitbox
@onready var sword_hitbox_shape: CollisionShape3D = $Visual/SwordHitbox/Shape
@onready var plunge_hitbox: Hitbox = $PlungeHitbox
@onready var body_shape: CollisionShape3D = $Collision


func _ready() -> void:
	add_to_group("player")
	health.max_health = stats.max_health
	health.heal_full()
	stamina = stats.max_stamina
	health.changed.connect(health_changed.emit)
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	sword_hitbox.hit_landed.connect(_on_hit_landed)
	plunge_hitbox.hit_landed.connect(_on_hit_landed)
	# Хитбокс меча меняет форму от стадии к стадии — делаем свою копию формы.
	_sword_shape = sword_hitbox_shape.shape.duplicate()
	sword_hitbox_shape.shape = _sword_shape
	arms = PlayerArms.new(visual, sword_pivot)
	body = PlayerBody.new(body_mesh, body_shape.shape as CapsuleShape3D)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	_state_time += delta
	_tick(delta)
	match state:
		State.MOVE: _move_state(delta)
		State.ROLL: _roll_state(delta)
		State.ATTACK: _attack_state(delta)
		State.PLUNGE: _plunge_state(delta)
		State.SLIDE: _slide_state(delta)
		State.CLIMB: _climb_state(delta)
		State.HURT: _hurt_state(delta)
		State.DEAD: _dead_state(delta)
		State.BLOCK: _block_state(delta)
		State.GUARD_BROKEN: _guard_broken_state(delta)
		State.CRITICAL: _critical_state(delta)
		State.BOW: _bow_state(delta)
		State.LEDGE_HANG: _ledge_hang_state(delta)
		State.LEDGE_CLIMB: _ledge_climb_state(delta)
	if _head_slide != 0.0:
		velocity.x = _head_slide * HEAD_SLIDE_SPEED
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0
	_limit_blocked_slide()
	_after_move()
	_check_enemy_head()
	_foley.update(is_on_floor(), velocity, global_position, delta, state == State.MOVE)
	_update_visual(delta)
	_reach.update_prompt(global_position, state != State.DEAD)
	if global_position.y < KILL_Y and state != State.DEAD:
		health.take_damage(INF)


# --- Таймеры и ввод ---------------------------------------------------------

func _tick(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_roll_buffer = maxf(_roll_buffer - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)
	_input_lock = maxf(_input_lock - delta, 0.0)
	_parry_t = maxf(_parry_t - delta, 0.0)
	_ledge_cooldown = maxf(_ledge_cooldown - delta, 0.0)
	_shoot_buffer = maxf(_shoot_buffer - delta, 0.0)
	_since_slide += delta
	_since_roll += delta
	hurtbox.invulnerable = _iframes > 0.0 or state == State.DEAD

	if state != State.DEAD:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = stats.jump_buffer
		if Input.is_action_just_pressed("attack"):
			_attack_buffer = stats.attack_buffer
		if Input.is_action_just_pressed("roll"):
			_roll_buffer = stats.input_buffer
		if Input.is_action_just_pressed("block"):
			_parry_t = stats.parry_window
		if Input.is_action_just_pressed("shoot"):
			_shoot_buffer = stats.input_buffer
		if Input.is_action_just_pressed("interact"):
			_try_interact()

	if _stamina_delay > 0.0:
		_stamina_delay -= delta
	elif stamina < stats.max_stamina:
		var regen := stats.stamina_regen * (stats.block_regen_mult if state == State.BLOCK else 1.0)
		stamina = minf(stamina + regen * delta, stats.max_stamina)
		stamina_changed.emit(stamina, stats.max_stamina)


func _input_x() -> float:
	if _input_lock > 0.0:
		return 0.0
	return Input.get_axis("move_left", "move_right")


func _spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_delay = stats.stamina_regen_delay
	stamina_changed.emit(stamina, stats.max_stamina)


func _set_state(new_state: State) -> void:
	if state == State.ATTACK:
		sword_hitbox.active = false
		if new_state != State.ATTACK:
			arms.rest()
	if state in [State.PLUNGE, State.BLOCK, State.GUARD_BROKEN, State.CRITICAL, State.LEDGE_HANG]:
		plunge_hitbox.active = false
		arms.rest()
	if state == State.BOW:
		arms.show_bow(false)
	if state == State.SLIDE:
		_since_slide = 0.0
	if state == State.ROLL:
		_since_roll = 0.0
	state = new_state
	_state_time = 0.0
	if state == State.BLOCK:
		arms.guard()
	elif state == State.GUARD_BROKEN:
		arms.guard_broken()
	elif state == State.LEDGE_HANG:
		# Руки заняты краем — меч прижат клинком вниз.
		arms.point_down()


func _apply_gravity(delta: float) -> void:
	var g := stats.gravity
	if velocity.y < 0.0:
		g *= stats.fall_multiplier
	elif not Input.is_action_pressed("jump"):
		g *= stats.jump_cut_multiplier
	velocity.y = maxf(velocity.y - g * delta, -stats.max_fall_speed)


# --- Состояния --------------------------------------------------------------

func _move_state(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = stats.coyote_time
	var x := _input_x()
	if x != 0.0:
		facing = signf(x)

	var target := x * stats.move_speed
	var accel := stats.acceleration if on_floor else stats.air_acceleration
	if x == 0.0:
		accel = stats.friction if on_floor else stats.air_drag
	# Импульс: скорость выше обычной (после ската или подката) гаснет медленно.
	if absf(velocity.x) > stats.move_speed and signf(velocity.x) == signf(target):
		accel = stats.momentum_decay
	velocity.x = move_toward(velocity.x, target, accel * delta)
	_apply_gravity(delta)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		_jump()
	elif _jump_buffer > 0.0 and not on_floor and is_instance_valid(_peg):
		_peg_jump()
	elif _roll_buffer > 0.0 and (on_floor or _coyote > 0.0):
		_start_roll()
	elif _attack_buffer > 0.0:
		if not on_floor and Input.is_action_pressed("move_down"):
			_start_plunge()
		else:
			_start_attack()
	elif _shoot_buffer > 0.0:
		_start_draw()
	elif on_floor and Input.is_action_pressed("block"):
		_set_state(State.BLOCK)
	elif _wants_climb(x, on_floor):
		_set_state(State.CLIMB)
	elif not on_floor and x != 0.0:
		_try_grab_ledge(signf(x))


func _jump() -> void:
	velocity.y = stats.jump_velocity
	Sfx.play(&"player_jump", global_position)
	_jump_buffer = 0.0
	_coyote = 0.0


func _start_roll() -> void:
	if stamina <= 0.0:
		return
	_roll_buffer = 0.0
	_spend_stamina(stats.roll_cost)
	var x := _input_x()
	_roll_dir = signf(x) if x != 0.0 else facing
	facing = _roll_dir
	# Подкат сохраняет скорость, если она больше обычной скорости переката.
	var carried := absf(velocity.x) if signf(velocity.x) == _roll_dir else 0.0
	_roll_speed = maxf(stats.roll_speed, carried)
	_iframes = maxf(_iframes, stats.roll_iframes)
	_roll_attack_queued = false
	_set_state(State.ROLL)
	Sfx.play(&"player_roll", global_position)


func _roll_state(delta: float) -> void:
	var t := _state_time / stats.roll_duration
	velocity.x = _roll_dir * _roll_speed * (1.0 - 0.4 * t)
	_apply_gravity(delta)
	# Удар, нажатый в кувырке, выходит сразу после него — «по инерции».
	if _attack_buffer > 0.0:
		_attack_buffer = 0.0
		_roll_attack_queued = true
	if _state_time >= stats.roll_duration:
		var queued := _roll_attack_queued
		_set_state(State.MOVE)
		if queued:
			_start_attack()


## Выбор удара: добивание или удар в спину → продолжение комбо → удар из скольжения
## → удар после кувырка → первая стадия комбо.
func _start_attack() -> void:
	if stamina <= 0.0 or weapon == null or weapon.combo.is_empty():
		return
	var x := _input_x()
	if x != 0.0 and state != State.SLIDE:
		facing = signf(x)
	if _try_critical():
		return
	if state == State.ATTACK:
		var chaining := _combo > 0 and _combo < weapon.combo.size()
		var index := _combo + 1 if chaining else 1
		_begin_attack(weapon.combo[index - 1], index)
	elif weapon.slide_attack and (state == State.SLIDE or _since_slide < stats.slide_attack_window):
		_begin_attack(weapon.slide_attack, 0)
	elif weapon.roll_attack and _since_roll < stats.roll_attack_window:
		_begin_attack(weapon.roll_attack, 0)
	else:
		_begin_attack(weapon.combo[0], 1)


## index — номер стадии комбо; 0 — особый удар, после него комбо начинается заново.
func _begin_attack(step: AttackStep, index: int) -> void:
	_attack_buffer = 0.0
	_spend_stamina(stats.attack_cost)
	_combo = index
	_step = step
	# Импульс переходит в удар: первый удар на высокой скорости тяжелее.
	_fast_attack = index <= 1 and absf(velocity.x) > stats.move_speed * 1.2
	var bonus := 1.3 if _fast_attack else 1.0
	sword_hitbox.damage = stats.sword_damage * step.damage_multiplier * bonus
	sword_hitbox.poise_damage = step.poise_damage * bonus
	sword_hitbox.heavy = step.heavy or _fast_attack
	sword_hitbox.knockback = maxf(step.knockback, 8.0 if _fast_attack else 0.0)
	_sword_shape.size = Vector3(step.hitbox_size.x, step.hitbox_size.y, 1.8)
	sword_hitbox_shape.position = Vector3(step.hitbox_offset.x, step.hitbox_offset.y, 0.0)
	_set_state(State.ATTACK)
	arms.swing(step)
	Sfx.play(&"sword_swing", global_position)
	attack_step_started.emit(step, index, weapon.combo.size())


func _attack_state(delta: float) -> void:
	var t := _state_time
	sword_hitbox.active = t >= _step.active_from and t <= _step.active_to
	var on_floor := is_on_floor()
	if _floor_glass_normal != Vector3.ZERO:
		# Удар в скольжении: скат продолжает нести героя.
		_slide_physics(delta)
	else:
		var lunge := facing * _step.lunge_speed if t < _step.active_to else 0.0
		var decel := stats.momentum_decay * 2.0 if on_floor else stats.air_acceleration * 0.5
		velocity.x = move_toward(velocity.x, lunge, decel * delta)
		_apply_gravity(delta)
	if t >= _step.chain_from:
		if _roll_buffer > 0.0 and on_floor:
			_start_roll()
			return
		if _attack_buffer > 0.0 and _combo < weapon.combo.size():
			_start_attack()
			return
	if t >= _step.duration:
		_set_state(State.SLIDE if _floor_glass_normal != Vector3.ZERO else State.MOVE)


func _start_plunge() -> void:
	if stamina <= 0.0:
		return
	_attack_buffer = 0.0
	_spend_stamina(stats.attack_cost)
	plunge_hitbox.damage = stats.sword_damage * 1.5
	plunge_hitbox.poise_damage = 45.0
	plunge_hitbox.heavy = true
	_plunge_landed_at = -1.0
	_set_state(State.PLUNGE)
	plunge_hitbox.active = true
	arms.point_down()


func _plunge_state(_delta: float) -> void:
	velocity.x = 0.0
	if _plunge_landed_at < 0.0:
		velocity.y = -stats.plunge_speed
		if is_on_floor():
			_plunge_landed_at = _state_time
			Events.camera_shake_requested.emit(0.2, 0.15)
	elif _state_time - _plunge_landed_at >= PLUNGE_LAND_TIME:
		_set_state(State.MOVE)
	elif not is_on_floor():
		# Пол под ногами разбит — продолжаем падать.
		_plunge_landed_at = -1.0


func _slide_state(delta: float) -> void:
	var down := _slide_physics(delta)
	apply_floor_snap()
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		if Input.is_action_pressed("move_down"):
			# Вниз + прыжок: разбиваемое стекло проваливается, неразбиваемое держит.
			if _floor_glass and _floor_glass.breakable:
				_floor_glass.shatter()
				_set_state(State.MOVE)
			return
		# Скорость со ската переносится в прыжок.
		velocity = Vector3(down.x * _slide_speed, stats.jump_velocity, 0.0)
		_set_state(State.MOVE)
	elif _roll_buffer > 0.0:
		_start_roll()
	elif _attack_buffer > 0.0:
		_start_attack()


## Разгон вдоль ската. Возвращает направление вниз по скату.
func _slide_physics(delta: float) -> Vector3:
	var down := _slope_down(_floor_glass_normal)
	_slide_dir = down
	facing = signf(down.x)
	_slide_speed += stats.gravity * stats.slide_gravity_scale * -down.y * delta
	_slide_speed += _input_x() * signf(down.x) * stats.slide_steer * delta
	_slide_speed = clampf(_slide_speed, -stats.move_speed, stats.max_slide_speed)
	velocity = down * _slide_speed
	return down


func _climb_state(_delta: float) -> void:
	var wall := _probe_glass_wall(facing)
	var v := 0.0 if _input_lock > 0.0 else Input.get_axis("move_down", "move_up")
	if wall == Vector3.ZERO:
		if v > 0.0:
			# Добрались до верха стены — подтягиваемся на уступ.
			velocity = Vector3(facing * 3.5, stats.mantle_velocity, 0.0)
		_set_state(State.MOVE)
		return
	facing = -signf(wall.x)
	velocity.x = -wall.x
	velocity.y = v * stats.climb_speed if v != 0.0 else -stats.climb_slip
	var x := _input_x()
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = Vector3(wall.x * stats.wall_jump_push, stats.jump_velocity * 0.95, 0.0)
		facing = signf(wall.x)
		_input_lock = 0.15
		_set_state(State.MOVE)
	elif x * wall.x > 0.5 or (is_on_floor() and v < 0.0):
		_set_state(State.MOVE)


# --- Уступы -------------------------------------------------------------------

## Зацеп за край (§5): в воздухе, держа направление к уступу. Край на уровне груди
## или головы — повисает на руках, край по пояс — сразу подтягивается.
func _try_grab_ledge(dir: float) -> bool:
	if _ledge_cooldown > 0.0 or velocity.y > stats.ledge_max_rise:
		return false
	var ledge := LedgeProbe.find(self, body_shape, dir, stats)
	if ledge == null:
		return false
	facing = dir
	_ledge_dir = dir
	_ledge_stand = ledge.stand
	velocity = Vector3.ZERO
	if ledge.vault:
		_ledge_hang = global_position
		_set_state(State.LEDGE_CLIMB)
	else:
		_ledge_hang = ledge.hang
		global_position = _ledge_hang
		_set_state(State.LEDGE_HANG)
	return true


## Стекло под ногами разбилось: летит вниз, не успевая схватиться за край.
func fall_through() -> void:
	_ledge_cooldown = maxf(_ledge_cooldown, stats.ledge_fall_through_block)


func _ledge_hang_state(_delta: float) -> void:
	velocity = Vector3.ZERO
	global_position = _ledge_hang
	var x := _input_x()
	var up := Input.is_action_pressed("move_up") or _jump_buffer > 0.0
	var toward := x * _ledge_dir > 0.5 and _state_time >= stats.ledge_auto_climb_delay
	if up or toward:
		_jump_buffer = 0.0
		_set_state(State.LEDGE_CLIMB)
	elif Input.is_action_pressed("move_down") or x * _ledge_dir < -0.5:
		_ledge_cooldown = stats.ledge_regrab_cooldown
		_set_state(State.MOVE)


## Подтягивание: сначала вверх вдоль стены, потом через край на уступ.
func _ledge_climb_state(_delta: float) -> void:
	velocity = Vector3.ZERO
	var t := clampf(_state_time / stats.ledge_climb_time, 0.0, 1.0)
	var rise := clampf(t / 0.6, 0.0, 1.0)
	var over := clampf((t - 0.6) / 0.4, 0.0, 1.0)
	global_position = Vector3(
		lerpf(_ledge_hang.x, _ledge_stand.x, over),
		lerpf(_ledge_hang.y, _ledge_stand.y, rise),
		0.0)
	if t >= 1.0:
		_coyote = stats.coyote_time
		_set_state(State.MOVE)


func _hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	_apply_gravity(delta)
	if _state_time >= HURT_TIME:
		_set_state(State.MOVE)


func _dead_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	_apply_gravity(delta)
	# Рука разжимается, когда тело начинает падать.
	if arms.dropped_weapon() == null and _state_time >= PlayerBody.SLUMP_TIME:
		arms.drop_weapon(get_parent(), facing)
	if not _death_landed and body.landed(_state_time):
		_death_landed = true
		Sfx.play(&"player_body_fall", global_position)


func _block_state(delta: float) -> void:
	var on_floor := is_on_floor()
	var x := _input_x()
	if x != 0.0:
		facing = signf(x)
	var target := x * stats.move_speed * stats.block_move_mult
	velocity.x = move_toward(velocity.x, target, stats.acceleration * delta)
	_apply_gravity(delta)
	if not on_floor or not Input.is_action_pressed("block"):
		_set_state(State.MOVE)
	elif _roll_buffer > 0.0:
		_start_roll()
	elif _jump_buffer > 0.0:
		_jump()
		_set_state(State.MOVE)
	elif _attack_buffer > 0.0:
		_start_attack()


func _guard_broken_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	_apply_gravity(delta)
	if _state_time >= stats.guard_break_time:
		_set_state(State.MOVE)


## Добивание и удар в спину: герой встаёт к врагу вплотную и наносит один тяжёлый удар.
func _try_critical() -> bool:
	if not is_on_floor():
		return false
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Dummy
		if enemy == null or not enemy.is_inside_tree():
			continue
		var d := enemy.global_position - global_position
		if absf(d.y) > 1.0 or signf(d.x) != facing:
			continue
		# У врага может быть своё особое добивание (§6.3).
		var riposte := enemy.riposte_step if enemy.riposte_step else weapon.riposte
		if riposte and enemy.can_be_riposted() and absf(d.x) <= stats.riposte_range:
			_start_critical(enemy, riposte)
			return true
		if weapon.backstab and enemy.can_be_backstabbed(global_position.x) \
				and absf(d.x) <= stats.backstab_range:
			_start_critical(enemy, weapon.backstab)
			return true
	return false


func _start_critical(enemy: Dummy, step: AttackStep) -> void:
	_attack_buffer = 0.0
	_critical_target = enemy
	_critical_done = false
	_critical_pierced = false
	_critical_holding = false
	_step = step
	_combo = 0
	facing = signf(enemy.global_position.x - global_position.x)
	var stand := enemy.global_position.x - facing * CRITICAL_DISTANCE
	move_and_collide(Vector3(stand - global_position.x, 0.0, 0.0))
	velocity = Vector3.ZERO
	enemy.begin_critical()
	_set_state(State.CRITICAL)
	if step.invulnerable:
		_iframes = maxf(_iframes, step.duration)
	arms.swing(step)
	attack_step_started.emit(step, 0, weapon.combo.size())


## Три фазы: клинок входит → враг висит на клинке → рывок, урон, врага сбрасывают.
func _critical_state(delta: float) -> void:
	velocity.x = 0.0
	_apply_gravity(delta)
	var held := _step.release_at > _step.active_to
	if not _critical_pierced and _state_time >= _step.active_from:
		_critical_pierced = true
		_critical_spark(0.6 if held else 1.0)
		Sfx.play(&"critical_pierce", global_position)
		if held and is_instance_valid(_critical_target):
			_critical_target.impale(_step.victim_lift, _step.release_at - _step.active_to)
	if held and not _critical_holding and _state_time >= _step.active_to:
		_critical_holding = true
		var hold := _step.release_at - _step.active_to
		arms.tween_blade(_step.blade_hold, _step.grip_hold, hold, Tween.TRANS_SINE)
	var release := _step.release_at if held else _step.active_from
	if not _critical_done and _state_time >= release:
		_critical_done = true
		if held:
			arms.tween_blade(_step.blade_release, _step.grip_release, 0.14, Tween.TRANS_QUAD)
			_critical_spark(1.0)
			Sfx.play(&"critical_release", global_position)
		if is_instance_valid(_critical_target):
			_critical_target.apply_critical(stats.sword_damage * _step.damage_multiplier,
				_step.victim_throw, global_position.x)
	if _state_time >= _step.duration:
		_set_state(State.MOVE)


func _critical_spark(strength: float) -> void:
	HitStop.stop(_step.hitstop * strength)
	Events.camera_shake_requested.emit(0.45 * strength, 0.3)
	if is_instance_valid(_critical_target):
		var at := _critical_target.global_position + Vector3(0.0, 1.1 + _step.victim_lift, 0.3)
		HitSpark.spawn(get_parent(), at, Color(1.0, 0.45, 0.3), int(32 * strength))


# --- Лук --------------------------------------------------------------------

func _start_draw() -> void:
	if stamina <= 0.0:
		return
	_shoot_buffer = 0.0
	_draw_t = 0.0
	_set_state(State.BOW)
	arms.show_bow(true)
	Sfx.play(&"bow_draw", global_position)


## Натяжение: держим кнопку — лук натягивается, герой идёт медленно. Отпустили — выстрел.
func _bow_state(delta: float) -> void:
	_draw_t = minf(_draw_t + delta / stats.bow_draw_time, 1.0)
	var x := _input_x()
	if x != 0.0:
		facing = signf(x)
	var accel := stats.acceleration if is_on_floor() else stats.air_acceleration
	velocity.x = move_toward(velocity.x, x * stats.move_speed * stats.bow_move_mult, accel * delta)
	_apply_gravity(delta)
	arms.draw_bow(_draw_t, _aim_angle())
	if _roll_buffer > 0.0 and is_on_floor():
		_start_roll()
	elif not Input.is_action_pressed("shoot"):
		_fire()


func _fire() -> void:
	var angle := _aim_angle()
	var dir := Vector3(cos(angle) * facing, sin(angle), 0.0)
	var speed := lerpf(stats.bow_speed_min, stats.bow_speed_max, _draw_t)
	var damage := lerpf(stats.bow_damage_min, stats.bow_damage_max, _draw_t)
	var poise_dmg := lerpf(stats.bow_poise_min, stats.bow_poise_max, _draw_t)
	var at := global_position + Vector3(facing * 0.55, 1.3, 0.0)
	var arrow := Arrow.spawn(get_parent(), at, dir * speed, damage, poise_dmg)
	_spend_stamina(stats.bow_cost)
	_set_state(State.MOVE)
	arrow_fired.emit(arrow)


## Прицел: прямо; с «вверх» — круто вверх; с «вниз» в воздухе — вниз.
func _aim_angle() -> float:
	if Input.is_action_pressed("move_up"):
		return deg_to_rad(stats.aim_up_angle)
	if Input.is_action_pressed("move_down") and not is_on_floor():
		return -deg_to_rad(stats.aim_down_angle)
	return 0.0


func set_peg(peg: ArrowPeg) -> void:
	_peg = peg


func clear_peg(peg: ArrowPeg) -> void:
	if _peg == peg:
		_peg = null


## Прыжок от воткнутой стрелы: вверх и от стены. Колышек ломается — только один раз.
func _peg_jump() -> void:
	_jump_buffer = 0.0
	velocity = Vector3(_peg.normal.x * stats.wall_jump_push, stats.jump_velocity, 0.0)
	if _peg.normal.x != 0.0:
		facing = signf(_peg.normal.x)
	_input_lock = 0.15
	_peg.break_off()
	Sfx.play(&"player_jump", global_position)
	_peg = null


# --- Стекло -----------------------------------------------------------------

func _after_move() -> void:
	_floor_glass = null
	_floor_glass_normal = _probe_glass_floor() if is_on_floor() else Vector3.ZERO
	# Сбежали с края прямо на скат — садимся на него, а не перелетаем (иначе рывок на стыке).
	# Окно — то же coyote time: пока капсула сходит с угла уступа, проба вниз упирается в угол.
	if state == State.MOVE and _coyote > 0.0 and not is_on_floor() and velocity.y <= 0.0:
		_snap_onto_slope()
	if state == State.MOVE and _floor_glass_normal != Vector3.ZERO:
		_slide_speed = velocity.dot(_slope_down(_floor_glass_normal))
		_set_state(State.SLIDE)
	elif state == State.SLIDE and _floor_glass_normal == Vector3.ZERO:
		# Сошли со стекла: скорость остаётся — импульс уходит в бег или полёт.
		velocity = _slide_dir * _slide_speed
		_set_state(State.MOVE)


## Упёрлись во врага на скате — скорость не копится, пока стоим.
func _limit_blocked_slide() -> void:
	var on_slope := _floor_glass_normal != Vector3.ZERO
	if not (state == State.SLIDE or (state == State.ATTACK and on_slope)):
		return
	var real := get_real_velocity().dot(_slide_dir)
	if real < _slide_speed * 0.5:
		_slide_speed = maxf(real, 0.0)


## Тела сталкиваются, но на врагах не стоят: с головы врага соскальзываем в сторону.
func _check_enemy_head() -> void:
	_head_slide = 0.0
	if not is_on_floor():
		return
	# Пробный сдвиг вниз: прилипание к опоре не всегда оставляет slide-коллизии.
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3(0.0, -0.1, 0.0), hit):
		return
	var enemy := hit.get_collider() as Dummy
	if enemy and hit.get_normal().y > 0.5:
		# Почти по центру — соскальзываем туда, куда смотрим (через врага, а не назад).
		var offset := global_position.x - enemy.global_position.x
		_head_slide = signf(offset) if absf(offset) > 0.25 else facing


func _slope_down(normal: Vector3) -> Vector3:
	var down := Vector3(normal.y, -normal.x, 0.0).normalized()
	return -down if down.y > 0.0 else down


func _wants_climb(x: float, on_floor: bool) -> bool:
	var up := Input.is_action_pressed("move_up")
	if not up and (on_floor or x == 0.0):
		return false
	var dir := signf(x) if x != 0.0 else facing
	var wall := _probe_glass_wall(dir)
	if wall == Vector3.ZERO:
		return false
	facing = dir
	return true


func _snap_onto_slope() -> void:
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3(0.0, -0.7, 0.0), hit):
		return
	var collider := hit.get_collider() as Node
	if collider and collider.is_in_group("glass_slide") and hit.get_normal().y > 0.3:
		global_position += hit.get_travel()
		_floor_glass = collider as GlassSurface
		_floor_glass_normal = hit.get_normal()


## Нормаль наклонного стекла под ногами или ZERO. Проверяем пробным сдвигом вниз:
## прилипание к полу не всегда оставляет slide-коллизии.
func _probe_glass_floor() -> Vector3:
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3(0.0, -0.2, 0.0), hit):
		return Vector3.ZERO
	var collider := hit.get_collider() as Node
	if collider and collider.is_in_group("glass_slide") and hit.get_normal().y > 0.3:
		_floor_glass = collider as GlassSurface
		return hit.get_normal()
	return Vector3.ZERO


## Нормаль стеклянной стены сбоку от игрока или ZERO, если стены нет.
func _probe_glass_wall(dir: float) -> Vector3:
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3(dir * 0.12, 0.0, 0.0), hit):
		return Vector3.ZERO
	var collider := hit.get_collider() as Node
	if collider and collider.is_in_group("glass_climb") and absf(hit.get_normal().y) < 0.3:
		return hit.get_normal()
	return Vector3.ZERO


# --- Бой --------------------------------------------------------------------

func _on_hit_landed(hurtbox_hit: Hurtbox) -> void:
	var hitbox := sword_hitbox if state == State.ATTACK else plunge_hitbox
	var stop := _step.hitstop if state == State.ATTACK and _step else 0.1
	HitStop.stop(maxf(stop, 0.1) if hitbox.heavy else stop)
	if hitbox.heavy:
		Events.camera_shake_requested.emit(0.25, 0.18)
	var at := hurtbox_hit.global_position + Vector3(0.0, 1.0, 0.3)
	HitSpark.spawn(get_parent(), at, Color(1.0, 0.85, 0.6))
	# Стекло звучит само (GlassSurface), здесь — только удар по врагу; звук задаёт стадия.
	if hurtbox_hit.owner is Dummy:
		Sfx.play(_step.hit_sound if state == State.ATTACK and _step else &"sword_hit", at)


func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	# Блок и парирование работают только против ударов врагов спереди.
	var attacker := hitbox.owner as Dummy
	if attacker and state not in [State.ROLL, State.GUARD_BROKEN, State.CRITICAL, State.HURT]:
		var from_front := signf(attacker.global_position.x - global_position.x) == facing
		if from_front and _parry_t > 0.0 and attacker.on_parried():
			_on_parry(attacker)
			return
		if from_front and state == State.BLOCK:
			_on_block(hitbox)
			return
	health.take_damage(hitbox.damage, hitbox.non_lethal)
	body.flash(Color(1.0, 0.25, 0.2))
	Sfx.play(&"player_hurt", global_position)
	Events.camera_shake_requested.emit(0.3, 0.2)
	if health.is_dead():
		return
	HitStop.stop(0.07)
	var dir := hitbox.knockback_direction(self)
	velocity = Vector3(dir.x * hitbox.knockback, 5.0, 0.0)
	_iframes = stats.hurt_iframes
	_set_state(State.HURT)


func _on_parry(attacker: Dummy) -> void:
	_parry_t = 0.0
	Sfx.play(&"sword_parry", global_position + Vector3(facing * 0.6, 1.2, 0.0))
	HitStop.stop(0.12)
	Events.camera_shake_requested.emit(0.3, 0.2)
	var at := (global_position + attacker.global_position) * 0.5 + Vector3(0.0, 1.2, 0.3)
	HitSpark.spawn(get_parent(), at, Color(1.0, 0.95, 0.6), 26)


## Удар принят на блок: урона нет, но он стоит выносливости. Не хватило — блок пробит.
func _on_block(hitbox: Hitbox) -> void:
	var cost := hitbox.damage * stats.block_stamina_mult
	var at := global_position + Vector3(facing * 0.6, 1.2, 0.3)
	# Пробитый блок звенит громче: клинок отбит.
	Sfx.play(&"sword_block", at, 0.0 if stamina >= cost else 4.0)
	if stamina >= cost:
		_spend_stamina(cost)
		velocity.x = -facing * 3.0
		HitStop.stop(0.05)
		body.flash(Color(0.6, 0.8, 1.0))
		HitSpark.spawn(get_parent(), at, Color(0.8, 0.9, 1.0), 12)
	else:
		_spend_stamina(stamina)
		velocity.x = -facing * 4.0
		Events.camera_shake_requested.emit(0.3, 0.2)
		HitSpark.spawn(get_parent(), at, Color(1.0, 0.6, 0.3), 18)
		_set_state(State.GUARD_BROKEN)


func _on_died() -> void:
	_set_state(State.DEAD)
	_death_landed = false
	_death_dir = body.fall_direction(self, facing)
	Sfx.play(&"player_knee", global_position)
	died.emit()
	Events.player_died.emit()


## Возрождение у осколка: полное здоровье и выносливость, короткая неуязвимость.
func respawn(at: Vector3) -> void:
	teleport(at)
	restore()
	_iframes = 1.0
	body_mesh.rotation = Vector3.ZERO
	arms.restore_weapon()
	_set_state(State.MOVE)


func teleport(at: Vector3) -> void:
	global_position = Vector3(at.x, at.y, 0.0)
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_peg = null
	_reach.prune()
	_jump_buffer = 0.0
	_attack_buffer = 0.0
	_roll_buffer = 0.0


func restore() -> void:
	health.heal_full()
	stamina = stats.max_stamina
	stamina_changed.emit(stamina, stats.max_stamina)


func is_dead() -> bool:
	return state == State.DEAD


# --- Взаимодействие ---------------------------------------------------------

func add_interactable(target: Interactable) -> void:
	_reach.add(target)


func remove_interactable(target: Interactable) -> void:
	_reach.remove(target)


func _try_interact() -> void:
	if state != State.MOVE or not is_on_floor():
		return
	var target := _reach.nearest(global_position)
	if target:
		target.interact(self)


# --- Визуал -----------------------------------------------------------------

func _update_visual(delta: float) -> void:
	# Разворот мгновенный: без интерполяции физики модель на кадр вставала
	# боком к камере, и металл меча ловил блик солнца.
	var yaw := 0.0 if facing > 0.0 else PI
	if visual.rotation.y != yaw:
		visual.rotation.y = yaw
		visual.reset_physics_interpolation()
	var k := 1.0 - exp(-18.0 * delta)
	var target_scale := Vector3.ONE
	var target_tilt := 0.0
	match state:
		State.ROLL:
			target_scale = Vector3(1.1, 0.6, 1.1)
		State.SLIDE:
			# Пригнулся и подался вперёд, удерживая равновесие.
			target_scale = Vector3(1.1, 0.75, 1.1)
			target_tilt = -SLIDE_LEAN
		State.CLIMB:
			target_scale = Vector3(0.9, 1.05, 0.9)
		State.BLOCK:
			target_scale = Vector3(1.05, 0.92, 1.05)
		State.GUARD_BROKEN:
			target_tilt = 0.3
		State.LEDGE_HANG:
			# Висит на вытянутых руках.
			target_scale = Vector3(0.88, 1.08, 0.88)
		State.LEDGE_CLIMB:
			target_scale = Vector3(1.05, 0.8, 1.05)
			target_tilt = -0.3
	if state == State.DEAD:
		body.death_pose(_state_time, _death_dir)
		return
	body_mesh.scale = body_mesh.scale.lerp(target_scale, k)
	body_mesh.position = Vector3(0.0, 0.9 * body_mesh.scale.y, 0.0)
	if state == State.ROLL:
		# Кувырок вперёд: полный оборот за время переката.
		body_mesh.rotation.z = -TAU * clampf(_state_time / stats.roll_duration, 0.0, 1.0)
	else:
		body_mesh.rotation.z = lerpf(wrapf(body_mesh.rotation.z, -PI, PI), target_tilt, k)
	# Мигание в неуязвимости после удара (перекат и особые удары не мигают).
	var blink := _iframes > 0.0 and state not in [State.ROLL, State.CRITICAL] \
		and fmod(_iframes, 0.12) < 0.06
	body_mesh.visible = not blink
