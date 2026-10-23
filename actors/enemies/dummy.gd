class_name Dummy
extends CharacterBody3D
## Враг-болванка для прототипа: патруль → заметил → телеграф → удар → откат.
## Удар можно прочитать: перед атакой тело наливается красным (§1.1, читаемый бой).
##
## Свойства типа врага — обязательные вопросы при создании нового врага (§6.3):
## стойкость, время разворота, поддаётся ли удару в спину, можно ли парировать.

enum State {
	DORMANT, PATROL, CHASE, WINDUP, ATTACK, RECOVER, STAGGER,
	OFF_BALANCE, CRITICAL_HIT, KNOCKDOWN, DEAD, INVESTIGATE,
}

const WINDUP_COLOR := Color(1.0, 0.35, 0.1)
const OFF_BALANCE_COLOR := Color(1.0, 0.85, 0.2)
const HEAD_SLIDE_SPEED := 5.0
## Страховка: если добивание так и не пришло, враг освобождается сам.
const CRITICAL_TIMEOUT := 2.0

@export var facing := -1.0
## Спит до раскрытия (засада за стеклом) — тогда сразу атакует.
@export var dormant := false
## Удары не добивают героя (первая засада в обучении не убивает, §5.3).
@export var non_lethal := false
@export var patrol_distance := 2.5
@export var patrol_speed := 1.8
@export var chase_speed := 3.2
## Видит героя перед собой на этом расстоянии.
@export var detect_range := 7.0
## Сзади замечает только вплотную — к врагу можно подкрасться.
@export var back_sense_range := 1.5
## Слышит шум (например, стрелу) на этом расстоянии, если не видит героя.
@export var hearing_range := 9.0
## Сколько осматривается на месте шума.
@export var investigate_look_time := 1.0
@export var attack_range := 1.8
@export var windup_time := 0.55
@export var attack_time := 0.18
@export var recover_time := 0.8
@export var stagger_time := 0.35
@export var gravity := 30.0
## Рывок вперёд в момент удара.
@export var attack_lunge := 5.0
@export var body_color := Color(0.42, 0.4, 0.44)

@export_group("Свойства типа врага")
## Запас стойкости: удары его снижают, при нуле — стаггер.
@export var max_poise := 50.0
@export var poise_regen := 25.0
@export var poise_regen_delay := 1.2
## Сколько секунд враг разворачивается. Медленный разворот — шанс ударить в спину.
@export var turn_time := 0.4
@export var backstab_allowed := true
@export var parry_allowed := true
@export var off_balance_time := 1.5
@export var knockdown_time := 0.8
## Особое добивание этого врага. Пусто — герой бьёт добиванием своего оружия.
@export var riposte_step: AttackStep
## Голос врага (события Sfx) поверх звука удара и падения. Пусто — безголосый (стекло, механизм).
@export var hurt_voice: StringName = &"enemy_hurt_voice"
@export var death_voice: StringName = &"enemy_death_voice"

var state := State.PATROL
var poise := 0.0

var _origin := Vector3.ZERO
var _state_time := 0.0
var _player: Player
var _material: StandardMaterial3D
var _flash := 0.0
var _lift_tween: Tween
var _head_slide := 0.0
var _poise_delay := 0.0
## Время с начала разворота; < 0 — не разворачивается.
var _turn_t := -1.0
var _noise_x := 0.0

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var attack_hitbox: Hitbox = $Visual/AttackHitbox


func _ready() -> void:
	add_to_group("enemy")
	_origin = global_position
	poise = max_poise
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_material.emission_enabled = true
	body_mesh.material_override = _material
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	attack_hitbox.non_lethal = non_lethal
	Events.noise_made.connect(_on_noise)
	state = State.DORMANT if dormant else State.PATROL


## Вызывается FlipX: враг в отражении смотрит в другую сторону.
func on_mirrored() -> void:
	facing = -facing


## Вызывается стеклом при разбивании: засада сразу бросается в атаку.
func on_revealed() -> void:
	_find_player()
	if _player:
		facing = signf(_player.global_position.x - global_position.x)
	_set_state(State.WINDUP)
	_state_time = windup_time * 0.4


func _physics_process(delta: float) -> void:
	if state == State.DORMANT:
		_wake_check(delta)
		return
	_state_time += delta
	_find_player()
	_regen_poise(delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	match state:
		State.PATROL: _patrol(delta)
		State.CHASE: _chase(delta)
		State.INVESTIGATE: _investigate(delta)
		State.WINDUP:
			_brake(30.0, delta)
			if _state_time >= windup_time:
				_set_state(State.ATTACK)
				attack_hitbox.active = true
				velocity.x = facing * attack_lunge
				_on_attack_started()
		State.ATTACK:
			_brake(20.0, delta)
			if _state_time >= attack_time:
				attack_hitbox.active = false
				_set_state(State.RECOVER)
		State.RECOVER:
			_brake(30.0, delta)
			if _state_time >= recover_time:
				_set_state(State.CHASE)
		State.STAGGER:
			_brake(25.0, delta)
			if _state_time >= stagger_time:
				_set_state(State.CHASE)
		State.OFF_BALANCE:
			_brake(20.0, delta)
			if _state_time >= off_balance_time:
				_set_state(State.CHASE)
		State.CRITICAL_HIT:
			velocity.x = 0.0
			if _state_time >= CRITICAL_TIMEOUT:
				if _lift_tween:
					_lift_tween.kill()
				visual.position.y = 0.0
				_set_state(State.KNOCKDOWN)
		State.KNOCKDOWN:
			_brake(25.0, delta)
			if _state_time >= knockdown_time:
				_set_state(State.CHASE)
		State.DEAD:
			_brake(25.0, delta)
	if _head_slide != 0.0:
		velocity.x = _head_slide * HEAD_SLIDE_SPEED
	velocity.z = 0.0
	move_and_slide()
	# Засада из ниши за стеклом выпрыгивает в плоскость боя.
	global_position.z = move_toward(global_position.z, 0.0, 12.0 * delta)
	_check_player_head()
	# Разворот мгновенный: без интерполяции физики модель на кадр вставала
	# боком к камере, и металл меча ловил блик солнца.
	var yaw := 0.0 if facing > 0.0 else PI
	if visual.rotation.y != yaw:
		visual.rotation.y = yaw
		visual.reset_physics_interpolation()
	_update_pose(delta)
	_update_material(delta)
	_update_extra(delta)


# --- Точки расширения для типов врагов --------------------------------------

## Пока враг спит (DORMANT): проверить, не пора ли проснуться.
func _wake_check(_delta: float) -> void:
	pass


func _on_attack_started() -> void:
	pass


## Удар закончился или прерван (парирование, стаггер, добивание).
func _on_attack_ended() -> void:
	pass


## Анимация, своя у типа врага.
func _update_extra(_delta: float) -> void:
	pass


func _brake(rate: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, rate * delta)


func _patrol(delta: float) -> void:
	if _sees_player(detect_range):
		_set_state(State.CHASE)
		return
	if _turn_t >= 0.0:
		_turn_towards(-facing, delta)
		_brake(30.0, delta)
		return
	velocity.x = facing * patrol_speed
	var offset := global_position.x - _origin.x
	if offset * facing > patrol_distance or _blocked_by_world():
		_turn_towards(-facing, delta)


func _chase(delta: float) -> void:
	# В погоне враг держит героя в обе стороны.
	if not _sees_player(detect_range * 1.5, false):
		_turn_t = -1.0
		_set_state(State.PATROL)
		return
	var dx := _player.global_position.x - global_position.x
	var want := signf(dx) if dx != 0.0 else facing
	if want != facing:
		# Разворот не мгновенный: пока враг разворачивается, ему можно ударить в спину.
		_turn_towards(want, delta)
		_brake(30.0, delta)
		return
	_turn_t = -1.0
	if absf(dx) <= attack_range:
		velocity.x = 0.0
		_set_state(State.WINDUP)
	else:
		velocity.x = facing * chase_speed


## Шум: враг, который не видит героя, идёт к месту шума и осматривается.
## Пока он смотрит на шум, к нему можно подкрасться со спины.
func _on_noise(at: Vector3, radius: float) -> void:
	if state not in [State.PATROL, State.INVESTIGATE] or not is_inside_tree():
		return
	if global_position.distance_to(at) > minf(radius, hearing_range):
		return
	if _sees_player(detect_range):
		return
	_noise_x = at.x
	_turn_t = -1.0
	_set_state(State.INVESTIGATE)


func _investigate(delta: float) -> void:
	if _sees_player(detect_range):
		_turn_t = -1.0
		_set_state(State.CHASE)
		return
	var dx := _noise_x - global_position.x
	if absf(dx) > 0.8:
		var want := signf(dx)
		if want != facing:
			_turn_towards(want, delta)
			_brake(30.0, delta)
			return
		velocity.x = facing * patrol_speed * 1.3
		# Осматриваться начнёт, когда дойдёт.
		_state_time = 0.0
		if _blocked_by_world():
			_noise_x = global_position.x
	else:
		_brake(30.0, delta)
		if _state_time >= investigate_look_time:
			_set_state(State.PATROL)


func _turn_towards(dir: float, delta: float) -> void:
	if _turn_t < 0.0:
		_turn_t = 0.0
	_turn_t += delta
	if _turn_t >= turn_time:
		facing = dir
		_turn_t = -1.0


func _regen_poise(delta: float) -> void:
	if _poise_delay > 0.0:
		_poise_delay -= delta
	else:
		poise = minf(poise + poise_regen * delta, max_poise)


# --- Защита героя: парирование, добивание, удар в спину ---------------------

## Герой парировал удар. Возвращает false, если этого врага парировать нельзя.
func on_parried() -> bool:
	if not parry_allowed or state == State.DEAD:
		return false
	attack_hitbox.active = false
	velocity.x = -facing * 2.0
	_set_state(State.OFF_BALANCE)
	return true


func can_be_riposted() -> bool:
	return state == State.OFF_BALANCE


## Герой стоит за спиной (по X), враг ещё не развернулся и поддаётся удару в спину.
func can_be_backstabbed(from_x: float) -> bool:
	if not backstab_allowed:
		return false
	if state in [State.DEAD, State.DORMANT, State.CRITICAL_HIT, State.KNOCKDOWN, State.OFF_BALANCE]:
		return false
	return signf(from_x - global_position.x) == -facing


## Начало добивания или удара в спину: враг зафиксирован до удара.
func begin_critical() -> void:
	attack_hitbox.active = false
	_turn_t = -1.0
	_set_state(State.CRITICAL_HIT)


## Клинок вошёл: враг повисает на нём, приподнятый на lift метров.
func impale(lift: float, time: float) -> void:
	_flash = 0.12
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_property(visual, "position:y", lift, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Клинок выдернут: урон, враг сброшен с клинка со скоростью throw (X — от героя).
func apply_critical(damage: float, throw: Vector2, from_x: float) -> void:
	if _lift_tween:
		_lift_tween.kill()
	visual.position.y = 0.0
	if state == State.DEAD:
		return
	health.take_damage(damage)
	_flash = 0.2
	if not health.is_dead():
		poise = max_poise
		_set_state(State.KNOCKDOWN)
		var away := signf(global_position.x - from_x)
		velocity = Vector3(away * throw.x, throw.y, 0.0)


# --- Попадания --------------------------------------------------------------

func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	health.take_damage(hitbox.damage)
	_flash = 0.12
	if health.is_dead():
		return
	Sfx.play(&"enemy_hurt", global_position)
	Sfx.play(hurt_voice, global_position)
	# В уязвимых состояниях реакции нет: враг и так беззащитен.
	if state in [State.CRITICAL_HIT, State.KNOCKDOWN, State.OFF_BALANCE]:
		return
	poise -= hitbox.poise_damage
	_poise_delay = poise_regen_delay
	var dir := hitbox.knockback_direction(self)
	if poise <= 0.0:
		# Стойкость сломана — направленный стаггер, враг разворачивается к обидчику.
		poise = max_poise
		velocity.x = dir.x * hitbox.knockback
		velocity.y = 3.0 if hitbox.heavy else 1.5
		facing = -dir.x
		_turn_t = -1.0
		_set_state(State.STAGGER)
	elif state in [State.PATROL, State.INVESTIGATE]:
		# Удар не сбил, но враг заметил героя.
		_set_state(State.CHASE)


func _on_died() -> void:
	_set_state(State.DEAD)
	Sfx.play(&"enemy_death", global_position)
	Sfx.play(death_voice, global_position)
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.35).set_delay(0.15)
	tween.tween_callback(queue_free)


# --- Общее ------------------------------------------------------------------

## Стена мира, а не герой: о героя патруль не разворачивается, просто упирается.
func _blocked_by_world() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if absf(c.get_normal().y) < 0.3 and not c.get_collider() is Player:
			return true
	return false


## Враг не стоит на голове героя — соскальзывает в сторону.
func _check_player_head() -> void:
	_head_slide = 0.0
	if not is_on_floor():
		return
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3(0.0, -0.1, 0.0), hit):
		return
	var player := hit.get_collider() as Player
	if player and hit.get_normal().y > 0.5:
		var offset := global_position.x - player.global_position.x
		_head_slide = signf(offset) if absf(offset) > 0.25 else facing


## Видит героя: спереди — на range_x, сзади — только вплотную (если front_only).
func _sees_player(range_x: float, front_only := true) -> bool:
	if _player == null or _player.is_dead():
		return false
	var d := _player.global_position - global_position
	if absf(d.y) >= 2.5:
		return false
	if front_only and signf(d.x) != facing and absf(d.x) > back_sense_range:
		return false
	return absf(d.x) < range_x


func _find_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player


func _set_state(new_state: State) -> void:
	if state == State.ATTACK:
		attack_hitbox.active = false
		_on_attack_ended()
	state = new_state
	_state_time = 0.0


## Поза: потерял равновесие — качается назад, сбит с ног — лежит.
func _update_pose(delta: float) -> void:
	var tilt := 0.0
	match state:
		State.OFF_BALANCE:
			tilt = 0.35 + sin(_state_time * 14.0) * 0.08
		State.CRITICAL_HIT:
			tilt = 0.25
		State.KNOCKDOWN:
			tilt = PI * 0.5
	body_mesh.rotation.z = lerpf(body_mesh.rotation.z, tilt, 1.0 - exp(-12.0 * delta))


func _update_material(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	var color := body_color
	var glow := 0.0
	if state == State.WINDUP:
		var t := clampf(_state_time / windup_time, 0.0, 1.0)
		color = body_color.lerp(WINDUP_COLOR, t)
		glow = t * 1.5
	elif state == State.OFF_BALANCE:
		var pulse := 0.5 + 0.5 * sin(_state_time * 18.0)
		color = body_color.lerp(OFF_BALANCE_COLOR, 0.6 + 0.4 * pulse)
		glow = 0.8 + pulse
	if _flash > 0.0:
		color = Color(1.0, 1.0, 1.0, body_color.a)
		glow = 2.0
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = glow
