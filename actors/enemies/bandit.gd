class_name Bandit
extends Dummy
## Мародёр с кладбища (§8.9, кадр 1.2): первые «разумные» враги. Действуют парой.
## HEAVY — с серебряным подсвечником: тяжёлый удар, отскакивает от замаха героя.
## KNIFE — с ножом: держится поодаль и метает ножи, а когда напарник наседает — заходит за спину.
## До встречи сидят в склепе (dormant); RobberEvent выпускает их наружу.

enum Kind { HEAVY, KNIFE }

const DODGE_SPEED := 7.0
const DODGE_COOLDOWN := 2.2
const THROW_COOLDOWN := 2.6
const KNIFE_SPEED := 13.0
const KNIFE_DAMAGE := 9.0
const KEEP_AWAY := 5.0

@export var kind := Kind.HEAVY
@export var partner_path: NodePath

var _dodge_wait := 1.0
var _throw_wait := 1.5
var _throwing := false
var _partner: Bandit


func _ready() -> void:
	super()
	_partner = get_node_or_null(partner_path) as Bandit


## Выпустить из засады: сразу в бой.
func wake() -> void:
	dormant = false
	_find_player()
	if _player:
		facing = signf(_player.global_position.x - global_position.x)
	_set_state(State.CHASE)


func _chase(delta: float) -> void:
	_dodge_wait -= delta
	_throw_wait -= delta
	if _player == null or _player.is_dead():
		super(delta)
		return
	var dx := _player.global_position.x - global_position.x
	# Герой замахнулся рядом — отскок.
	if _dodge_wait <= 0.0 and absf(dx) < 2.4 and _player.state == Player.State.ATTACK:
		_dodge_wait = DODGE_COOLDOWN
		facing = signf(dx)
		velocity.x = -facing * DODGE_SPEED
		velocity.y = 3.0
		_set_state(State.RECOVER)
		recover_time = 0.35
		return
	if kind == Kind.KNIFE:
		var partner_busy := _partner != null and is_instance_valid(_partner) and _partner.state in [State.WINDUP, State.ATTACK, State.RECOVER]
		if partner_busy and absf(dx) < 7.0:
			# Заходит за спину герою.
			var behind := _player.global_position.x - _player.facing * 1.4
			var to := behind - global_position.x
			facing = signf(dx) if absf(to) < 0.4 else signf(to)
			velocity.x = 0.0 if absf(to) < 0.4 else signf(to) * chase_speed * 1.2
			if absf(to) < 0.4 or absf(dx) <= attack_range:
				facing = signf(dx)
				_throwing = false
				_set_state(State.WINDUP)
			return
		if absf(dx) > attack_range and _throw_wait <= 0.0:
			_throw_wait = THROW_COOLDOWN
			facing = signf(dx)
			_throwing = true
			_set_state(State.WINDUP)
			return
		if absf(dx) < KEEP_AWAY and not partner_busy and _partner != null and is_instance_valid(_partner) and _partner.state != State.DEAD:
			# Держится поодаль, пока напарник не займёт героя.
			facing = signf(dx)
			velocity.x = -facing * chase_speed * 0.7
			return
	_throwing = false
	super(delta)


func _set_state(new_state: State) -> void:
	if new_state == State.WINDUP:
		match kind:
			Kind.HEAVY:
				windup_time = 0.6
				attack_lunge = 5.0
				recover_time = 0.8
			Kind.KNIFE:
				windup_time = 0.4 if _throwing else 0.3
				attack_lunge = 0.0 if _throwing else 6.0
				recover_time = 0.5
	super(new_state)


func _on_attack_started() -> void:
	Sfx.play(&"sword_swing", global_position, -2.0)
	if _throwing:
		attack_hitbox.active = false
		_throw_knife()


func _throw_knife() -> void:
	var knife := Hitbox.new()
	knife.collision_layer = 0
	knife.collision_mask = 1 << 1
	knife.damage = KNIFE_DAMAGE
	knife.knockback = 3.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.2, 1.2)
	shape.shape = box
	knife.add_child(shape)
	var mesh := MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.45, 0.06, 0.08)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.75, 0.8)
	material.metallic = 0.8
	blade.material = material
	mesh.mesh = blade
	knife.add_child(mesh)
	get_parent().add_child(knife)
	knife.global_position = global_position + Vector3(facing * 0.7, 1.3, 0.0)
	knife.active = true
	var flight := knife.create_tween()
	flight.tween_property(knife, "global_position:x", knife.global_position.x + facing * KNIFE_SPEED * 1.0, 1.0)
	flight.parallel().tween_property(mesh, "rotation:z", facing * -TAU * 3.0, 1.0)
	flight.tween_callback(knife.queue_free)
	knife.hit_landed.connect(func(_h: Hurtbox) -> void: knife.queue_free())
