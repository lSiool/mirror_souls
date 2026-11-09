class_name Bat
extends Dummy
## Летучая мышь: висит под балкой вниз головой, пока герой не подойдёт, потом кружит над ним
## и пикирует. Перед пике замирает и наливается красным: удар можно прочитать. Единственный
## момент, когда её легко достать мечом. Упав, падает на пол. Сквозь героя пролетает.

## С какого расстояния просыпается.
@export var wake_range_x := 6.5
@export var wake_range_y := 3.6
@export var hover_height := 2.5
@export var hover_speed := 4.5
@export var hover_time := 1.5
@export var dive_speed := 9.0

var _awake := false
var _time := 0.0
var _dive_to := Vector3.ZERO

@onready var wing_left: Node3D = $Visual/WingLeft
@onready var wing_right: Node3D = $Visual/WingRight


func _init() -> void:
	creature = CreatureKind.Kind.BEAST


func _ready() -> void:
	super()
	state = State.PATROL
	# Висит вниз головой, крылья сложены.
	wing_left.rotation.z = -1.2
	wing_right.rotation.z = 1.2


func _physics_process(delta: float) -> void:
	_find_player()
	_state_time += delta * statuses.time_mult()
	_time += delta
	if state == State.DEAD:
		velocity.x = 0.0
		velocity.y -= gravity * delta
		move_and_slide()
		_update_material(delta)
		return
	if not _awake:
		if _player and not _player.is_dead() \
				and absf(_player.global_position.x - global_position.x) < wake_range_x \
				and absf(_player.global_position.y - global_position.y) < wake_range_y:
			_awake = true
			_set_state(State.PATROL)
		_update_material(delta)
		return
	match state:
		State.PATROL: _hover()
		State.WINDUP:
			velocity = velocity.lerp(Vector3.ZERO, minf(1.0, 8.0 * delta))
			if _state_time >= windup_time:
				_dive_to = _chest()
				_set_state(State.ATTACK)
				attack_hitbox.active = true
		State.ATTACK:
			var to_goal := _dive_to - global_position
			velocity = to_goal.normalized() * dive_speed
			if to_goal.length() < 0.3 or _state_time >= attack_time:
				attack_hitbox.active = false
				_set_state(State.RECOVER)
		State.BLINDED:
			# Ослеп (призрак): отплывает от героя и вверх, пока слепота не кончится.
			velocity = velocity.lerp(Vector3(-facing * 1.2, 0.6, 0.0), minf(1.0, 3.0 * delta))
		_:
			velocity = velocity.lerp(Vector3(0.0, hover_speed * 0.6, 0.0), minf(1.0, 6.0 * delta))
			if _state_time >= recover_time:
				_set_state(State.PATROL)
	velocity.z = 0.0
	# Смола на крыльях — только от прямых брызг склянки.
	var mult := statuses.speed_mult()
	velocity *= mult
	move_and_slide()
	velocity /= mult
	global_position.z = 0.0
	if _player and absf(_player.global_position.x - global_position.x) > 0.2:
		facing = signf(_player.global_position.x - global_position.x)
	var flap := sin(_time * 22.0) * 0.6
	wing_left.rotation.z = -flap
	wing_right.rotation.z = flap
	_update_material(delta)


## Летучая мышь летает по эхолокации: свет её не слепит (§6.2), хоть она и зверь.
func _status_reaction(id: StringName) -> CreatureKind.Reaction:
	if id == Statuses.BLIND and creature == CreatureKind.Kind.BEAST:
		return CreatureKind.Reaction.IMMUNE
	return super(id)


## Кружит над героем; пора — замирает перед пике.
func _hover() -> void:
	if _player == null or _player.is_dead():
		velocity = Vector3.ZERO
		return
	var goal := _player.global_position + Vector3(sin(_time * 1.4) * 2.2, hover_height, 0.0)
	velocity = (goal - global_position).limit_length(hover_speed)
	if _state_time >= hover_time:
		_set_state(State.WINDUP)


func _chest() -> Vector3:
	return _player.global_position + Vector3(0.0, 1.1, 0.0) if _player else global_position


## Удар сбивает пике и отбрасывает её вверх; стойки у неё нет.
func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	last_weapon = hitbox.weapon_type
	health.take_damage(hitbox.damage)
	_flash = 0.12
	if health.is_dead():
		return
	Sfx.play(&"enemy_hurt", global_position)
	_add_bleed(hitbox.bleed)
	if health.is_dead():
		return
	_awake = true
	attack_hitbox.active = false
	velocity = hitbox.knockback_direction(self) * 4.0 + Vector3(0.0, 3.0, 0.0)
	# Слепого удар отбрасывает, но не будит.
	if state != State.BLINDED:
		_set_state(State.RECOVER)
