class_name Dummy
extends CharacterBody3D
## Враг-болванка для прототипа: патруль → заметил → телеграф → удар → откат.
## Удар можно прочитать: перед атакой тело наливается красным (§1.1, читаемый бой).

enum State { DORMANT, PATROL, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD }

const BASE_COLOR := Color(0.42, 0.4, 0.44)
const WINDUP_COLOR := Color(1.0, 0.35, 0.1)
const HEAD_SLIDE_SPEED := 5.0

@export var facing := -1.0
## Спит до раскрытия (засада за стеклом) — тогда сразу атакует.
@export var dormant := false
## Удары не добивают героя (первая засада в обучении не убивает, §5.3).
@export var non_lethal := false
@export var patrol_distance := 2.5
@export var patrol_speed := 1.8
@export var chase_speed := 3.2
@export var detect_range := 7.0
@export var attack_range := 1.8
@export var windup_time := 0.55
@export var attack_time := 0.18
@export var recover_time := 0.8
@export var stagger_time := 0.35
@export var gravity := 30.0

var state := State.PATROL

var _origin := Vector3.ZERO
var _state_time := 0.0
var _player: Player
var _material: StandardMaterial3D
var _flash := 0.0
var _head_slide := 0.0

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var attack_hitbox: Hitbox = $Visual/AttackHitbox


func _ready() -> void:
	_origin = global_position
	_material = StandardMaterial3D.new()
	_material.albedo_color = BASE_COLOR
	_material.emission_enabled = true
	body_mesh.material_override = _material
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	attack_hitbox.non_lethal = non_lethal
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
		return
	_state_time += delta
	_find_player()
	if not is_on_floor():
		velocity.y -= gravity * delta
	match state:
		State.PATROL: _patrol()
		State.CHASE: _chase()
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			if _state_time >= windup_time:
				_set_state(State.ATTACK)
				attack_hitbox.active = true
				velocity.x = facing * 5.0
		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			if _state_time >= attack_time:
				attack_hitbox.active = false
				_set_state(State.RECOVER)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			if _state_time >= recover_time:
				_set_state(State.CHASE)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
			if _state_time >= stagger_time:
				_set_state(State.CHASE)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
	if _head_slide != 0.0:
		velocity.x = _head_slide * HEAD_SLIDE_SPEED
	velocity.z = 0.0
	move_and_slide()
	# Засада из ниши за стеклом выпрыгивает в плоскость боя.
	global_position.z = move_toward(global_position.z, 0.0, 12.0 * delta)
	_check_player_head()
	visual.rotation.y = 0.0 if facing > 0.0 else PI
	_update_material(delta)


func _patrol() -> void:
	velocity.x = facing * patrol_speed
	var offset := global_position.x - _origin.x
	var at_edge := offset * facing > patrol_distance
	if at_edge or _blocked_by_world():
		facing = -facing
	if _sees_player(detect_range):
		_set_state(State.CHASE)


func _chase() -> void:
	if not _sees_player(detect_range * 1.5):
		_set_state(State.PATROL)
		return
	var dx := _player.global_position.x - global_position.x
	facing = signf(dx) if dx != 0.0 else facing
	if absf(dx) <= attack_range:
		velocity.x = 0.0
		_set_state(State.WINDUP)
	else:
		velocity.x = facing * chase_speed


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


func _sees_player(range_x: float) -> bool:
	if _player == null or _player.is_dead():
		return false
	var d := _player.global_position - global_position
	return absf(d.x) < range_x and absf(d.y) < 2.5


func _find_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player


func _set_state(new_state: State) -> void:
	if state == State.ATTACK:
		attack_hitbox.active = false
	state = new_state
	_state_time = 0.0


func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	health.take_damage(hitbox.damage)
	_flash = 0.12
	if health.is_dead():
		return
	var dir := hitbox.knockback_direction(self)
	velocity.x = dir.x * hitbox.knockback
	velocity.y = 3.0 if hitbox.heavy else 1.5
	# Стаггер направленный: враг разворачивается к обидчику.
	facing = -dir.x
	_set_state(State.STAGGER)


func _on_died() -> void:
	_set_state(State.DEAD)
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.35).set_delay(0.15)
	tween.tween_callback(queue_free)


func _update_material(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	var color := BASE_COLOR
	var glow := 0.0
	if state == State.WINDUP:
		var t := clampf(_state_time / windup_time, 0.0, 1.0)
		color = BASE_COLOR.lerp(WINDUP_COLOR, t)
		glow = t * 1.5
	if _flash > 0.0:
		color = Color.WHITE
		glow = 2.0
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = glow
