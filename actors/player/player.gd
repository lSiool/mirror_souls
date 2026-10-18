class_name Player
extends CharacterBody3D
## Герой: движение в плоскости XY, перекат, меч, удар вниз, скольжение и лазание по стеклу.
## Все числа скорости и урона берутся из PlayerStats, который зависит от возраста (§1.3).

signal died
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)

enum State { MOVE, ROLL, ATTACK, PLUNGE, SLIDE, CLIMB, HURT, DEAD }

const KILL_Y := -15.0
const ATTACK_ACTIVE_FROM := 0.07
const ATTACK_ACTIVE_TO := 0.2
const ATTACK_CHAIN_FROM := 0.17
const ATTACK_DURATION := 0.36
const PLUNGE_LAND_TIME := 0.15
const HURT_TIME := 0.3
const MAX_COMBO := 2

@export var stats: PlayerStats

var state := State.MOVE
var facing := 1.0
var stamina := 0.0
## Пока true — игрок не управляется (переход через зеркало, затемнение).
var frozen := false

var _state_time := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _attack_buffer := 0.0
var _roll_buffer := 0.0
var _iframes := 0.0
var _stamina_delay := 0.0
var _input_lock := 0.0
var _combo := 0
var _roll_dir := 1.0
var _roll_speed := 0.0
var _plunge_landed_at := -1.0
var _floor_glass_normal := Vector3.ZERO
## Скорость вдоль ската. Храним сами: move_and_slide() на склоне срезает вертикаль у velocity.
var _slide_speed := 0.0
var _slide_dir := Vector3.RIGHT
var _interactables: Array[Interactable] = []
var _prompt := ""
var _swing_tween: Tween

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var sword_pivot: Node3D = $Visual/SwordPivot
@onready var sword_hitbox: Hitbox = $Visual/SwordHitbox
@onready var plunge_hitbox: Hitbox = $PlungeHitbox


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
	_rest_sword()


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
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0
	_after_move()
	_update_visual(delta)
	_update_prompt()
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
	hurtbox.invulnerable = _iframes > 0.0 or state == State.DEAD

	if state != State.DEAD:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = stats.jump_buffer
		if Input.is_action_just_pressed("attack"):
			_attack_buffer = stats.input_buffer
		if Input.is_action_just_pressed("roll"):
			_roll_buffer = stats.input_buffer
		if Input.is_action_just_pressed("interact"):
			_try_interact()

	if _stamina_delay > 0.0:
		_stamina_delay -= delta
	elif stamina < stats.max_stamina:
		stamina = minf(stamina + stats.stamina_regen * delta, stats.max_stamina)
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
			_rest_sword()
	if state == State.PLUNGE:
		plunge_hitbox.active = false
		_rest_sword()
	state = new_state
	_state_time = 0.0


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
	if x == 0.0 and on_floor:
		accel = stats.friction
	# Импульс: скорость выше обычной (после ската или подката) гаснет медленно.
	if absf(velocity.x) > stats.move_speed and signf(velocity.x) == signf(target):
		accel = stats.momentum_decay
	velocity.x = move_toward(velocity.x, target, accel * delta)
	_apply_gravity(delta)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		_jump()
	elif _roll_buffer > 0.0 and (on_floor or _coyote > 0.0):
		_start_roll()
	elif _attack_buffer > 0.0:
		if not on_floor and Input.is_action_pressed("move_down"):
			_start_plunge()
		else:
			_start_attack()
	elif _wants_climb(x, on_floor):
		_set_state(State.CLIMB)


func _jump() -> void:
	velocity.y = stats.jump_velocity
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
	_set_state(State.ROLL)


func _roll_state(delta: float) -> void:
	var t := _state_time / stats.roll_duration
	velocity.x = _roll_dir * _roll_speed * (1.0 - 0.4 * t)
	_apply_gravity(delta)
	if _state_time >= stats.roll_duration:
		_set_state(State.MOVE)


func _start_attack() -> void:
	if stamina <= 0.0:
		return
	_attack_buffer = 0.0
	_spend_stamina(stats.attack_cost)
	_combo = _combo + 1 if state == State.ATTACK else 1
	var x := _input_x()
	if x != 0.0:
		facing = signf(x)
	# Импульс переходит в удар: на высокой скорости первый удар тяжелее.
	var fast := absf(velocity.x) > stats.move_speed * 1.2
	var heavy := _combo >= MAX_COMBO or fast
	sword_hitbox.damage = stats.sword_damage * (1.3 if heavy else 1.0)
	sword_hitbox.heavy = heavy
	sword_hitbox.knockback = 8.0 if heavy else 4.5
	_set_state(State.ATTACK)
	_swing(_combo)


func _attack_state(delta: float) -> void:
	var t := _state_time
	sword_hitbox.active = t >= ATTACK_ACTIVE_FROM and t <= ATTACK_ACTIVE_TO
	var on_floor := is_on_floor()
	var lunge := facing * stats.attack_lunge if t < ATTACK_ACTIVE_TO else 0.0
	var decel := stats.momentum_decay * 2.0 if on_floor else stats.air_acceleration * 0.5
	velocity.x = move_toward(velocity.x, lunge, decel * delta)
	_apply_gravity(delta)
	if t >= ATTACK_CHAIN_FROM:
		if _roll_buffer > 0.0 and on_floor:
			_start_roll()
			return
		if _attack_buffer > 0.0 and _combo < MAX_COMBO:
			_start_attack()
			return
	if t >= ATTACK_DURATION:
		_set_state(State.MOVE)


func _start_plunge() -> void:
	if stamina <= 0.0:
		return
	_attack_buffer = 0.0
	_spend_stamina(stats.attack_cost)
	plunge_hitbox.damage = stats.sword_damage * 1.5
	plunge_hitbox.heavy = true
	_plunge_landed_at = -1.0
	_set_state(State.PLUNGE)
	plunge_hitbox.active = true
	_point_sword_down()


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
	var down := _slope_down(_floor_glass_normal)
	_slide_dir = down
	facing = signf(down.x)
	_slide_speed += stats.gravity * stats.slide_gravity_scale * -down.y * delta
	_slide_speed += _input_x() * signf(down.x) * stats.slide_steer * delta
	_slide_speed = clampf(_slide_speed, -stats.move_speed, stats.max_slide_speed)
	velocity = down * _slide_speed

	if _jump_buffer > 0.0:
		# Скорость со ската переносится в прыжок.
		_jump_buffer = 0.0
		velocity = Vector3(down.x * _slide_speed, stats.jump_velocity, 0.0)
		_set_state(State.MOVE)
	elif _roll_buffer > 0.0:
		_start_roll()
	elif _attack_buffer > 0.0:
		_start_attack()


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


func _hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	_apply_gravity(delta)
	if _state_time >= HURT_TIME:
		_set_state(State.MOVE)


func _dead_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	_apply_gravity(delta)


# --- Стекло -----------------------------------------------------------------

func _after_move() -> void:
	_floor_glass_normal = _probe_glass_floor() if is_on_floor() else Vector3.ZERO
	if state == State.MOVE and _floor_glass_normal != Vector3.ZERO:
		_slide_speed = velocity.dot(_slope_down(_floor_glass_normal))
		_set_state(State.SLIDE)
	elif state == State.SLIDE and _floor_glass_normal == Vector3.ZERO:
		# Сошли со стекла: скорость остаётся — импульс уходит в бег или полёт.
		velocity = _slide_dir * _slide_speed
		_set_state(State.MOVE)


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


## Нормаль наклонного стекла под ногами или ZERO. Проверяем пробным сдвигом вниз:
## прилипание к полу не всегда оставляет slide-коллизии.
func _probe_glass_floor() -> Vector3:
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3(0.0, -0.2, 0.0), hit):
		return Vector3.ZERO
	var collider := hit.get_collider() as Node
	if collider and collider.is_in_group("glass_slide") and hit.get_normal().y > 0.3:
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
	HitStop.stop(0.1 if hitbox.heavy else 0.06)
	if hitbox.heavy:
		Events.camera_shake_requested.emit(0.25, 0.18)
	var at := hurtbox_hit.global_position + Vector3(0.0, 1.0, 0.3)
	HitSpark.spawn(get_parent(), at, Color(1.0, 0.85, 0.6))


func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	health.take_damage(hitbox.damage, hitbox.non_lethal)
	_flash(Color(1.0, 0.25, 0.2))
	Events.camera_shake_requested.emit(0.3, 0.2)
	if health.is_dead():
		return
	HitStop.stop(0.07)
	var dir := hitbox.knockback_direction(self)
	velocity = Vector3(dir.x * hitbox.knockback, 5.0, 0.0)
	_iframes = stats.hurt_iframes
	_set_state(State.HURT)


func _on_died() -> void:
	_set_state(State.DEAD)
	died.emit()
	Events.player_died.emit()


## Возрождение у осколка: полное здоровье и выносливость, короткая неуязвимость.
func respawn(at: Vector3) -> void:
	teleport(at)
	restore()
	_iframes = 1.0
	body_mesh.rotation = Vector3.ZERO
	_set_state(State.MOVE)


func teleport(at: Vector3) -> void:
	global_position = Vector3(at.x, at.y, 0.0)
	velocity = Vector3.ZERO
	_interactables.clear()
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
	if target not in _interactables:
		_interactables.append(target)


func remove_interactable(target: Interactable) -> void:
	_interactables.erase(target)


func _current_interactable() -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for target in _interactables:
		if not is_instance_valid(target) or not target.enabled or not target.is_inside_tree():
			continue
		var d := global_position.distance_to(target.global_position)
		if d < best_distance:
			best = target
			best_distance = d
	return best


func _try_interact() -> void:
	if state != State.MOVE or not is_on_floor():
		return
	var target := _current_interactable()
	if target:
		target.interact(self)


func _update_prompt() -> void:
	var target := _current_interactable() if state != State.DEAD else null
	var text := target.prompt if target else ""
	if text != _prompt:
		_prompt = text
		Events.interact_prompt_changed.emit(text)


# --- Визуал -----------------------------------------------------------------

func _update_visual(delta: float) -> void:
	visual.rotation.y = 0.0 if facing > 0.0 else PI
	var target_scale := Vector3.ONE
	match state:
		State.ROLL:
			target_scale = Vector3(1.2, 0.55, 1.2)
		State.SLIDE:
			target_scale = Vector3(1.15, 0.75, 1.15)
		State.CLIMB:
			target_scale = Vector3(0.9, 1.05, 0.9)
	body_mesh.scale = body_mesh.scale.lerp(target_scale, 1.0 - exp(-18.0 * delta))
	body_mesh.position.y = 0.9 * body_mesh.scale.y
	if state == State.DEAD:
		body_mesh.rotation.z = lerpf(body_mesh.rotation.z, -PI * 0.5, 1.0 - exp(-8.0 * delta))
	# Мигание в неуязвимости после удара (перекат не мигает).
	var blink := _iframes > 0.0 and state != State.ROLL and fmod(_iframes, 0.12) < 0.06
	body_mesh.visible = not blink


func _flash(color: Color) -> void:
	var mat := body_mesh.get_active_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	var tween := create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.25)


func _swing(combo: int) -> void:
	if _swing_tween:
		_swing_tween.kill()
	var from := 1.4 if combo % 2 == 1 else -1.9
	var to := -1.9 if combo % 2 == 1 else 1.2
	sword_pivot.rotation.z = from
	_swing_tween = create_tween()
	_swing_tween.tween_property(sword_pivot, "rotation:z", to, ATTACK_ACTIVE_TO - ATTACK_ACTIVE_FROM) \
		.set_delay(ATTACK_ACTIVE_FROM).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _point_sword_down() -> void:
	if _swing_tween:
		_swing_tween.kill()
	sword_pivot.rotation.z = PI


func _rest_sword() -> void:
	if _swing_tween:
		_swing_tween.kill()
	sword_pivot.rotation.z = 0.5
