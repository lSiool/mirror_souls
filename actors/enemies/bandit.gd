class_name Bandit
extends Dummy
## Мародёр с кладбища (§8.9, кадр 1.2): первые «разумные» враги. Действуют парой.
## HEAVY — с серебряным подсвечником: бьёт ударами молота (§6.2) — теми же, что герой с подсвечником,
## но с долгим замахом; отскакивает от замаха героя, погибнув — роняет подсвечник.
## KNIFE — с ножом: держится поодаль и метает ножи, а когда напарник наседает — заходит за спину.
## До встречи сидят в склепе (dormant); RobberEvent выпускает их наружу.

enum Kind { HEAVY, KNIFE }

const DODGE_SPEED := 7.0
const DODGE_COOLDOWN := 2.2
const THROW_COOLDOWN := 2.6
const KNIFE_SPEED := 13.0
const KNIFE_DAMAGE := 9.0
const KEEP_AWAY := 5.0
## Подсвечник — молот низкого качества: его удары и позы. Герой получает его с мародёра.
const CANDLESTICK := preload("res://data/weapons/candlestick.tres")
const CANDLESTICK_FLAG := &"got_candlestick"
## Урон удара подсвечником до множителя стадии; замах — телеграф, у удара сверху дольше.
const HEAVY_DAMAGE := 13.0
const HEAVY_WINDUP := 0.6
const OVERHEAD_WINDUP := 0.85
## Оружие после удара ещё лежит: столько сверх стадии враг открыт.
const HEAVY_RECOVER_EXTRA := 0.3

@export var kind := Kind.HEAVY
@export var partner_path: NodePath

var _dodge_wait := 1.0
var _throw_wait := 1.5
var _throwing := false
var _partner: Bandit
## Удары молота по кругу: с плеча наискось, подхват, удар сверху.
var _moves: Array[AttackStep] = []
var _move_i := 0
var _move: AttackStep
var _prop: Node3D
var _prop_base := Vector3.ZERO
var _attack_shape: BoxShape3D
var _attack_shape_node: CollisionShape3D


func _ready() -> void:
	super()
	_partner = get_node_or_null(partner_path) as Bandit
	_prop = get_node_or_null(^"Visual/PropPivot") as Node3D
	if kind == Kind.HEAVY:
		_moves = CANDLESTICK.combo_at(WeaponData.STEP_EXTRA_HIT)
		_attack_shape_node = attack_hitbox.get_child(0) as CollisionShape3D
		_attack_shape = _attack_shape_node.shape.duplicate() as BoxShape3D
		_attack_shape_node.shape = _attack_shape
	if _prop:
		_prop_base = _prop.position
		_pose(CANDLESTICK.rest_blade, CANDLESTICK.rest_grip)
		# Подсвечник встал в позу — кисти на него.
		_update_arms(0.0)


## Руки graybox (§6.3): подсвечник — двумя руками за древко, нож — одной за рукоять.
func _grip_node() -> Node3D:
	return get_node_or_null(^"Visual/PropPivot" if kind == Kind.HEAVY else ^"Visual/Prop") as Node3D


func _grip_points() -> Array[Vector3]:
	if kind == Kind.HEAVY:
		return [Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.42, 0.0)]
	return [Vector3(-0.18, 0.0, 0.0)]


## Нож лежит вдоль X.
func _weapon_axis() -> Vector3:
	return Vector3.UP if kind == Kind.HEAVY else Vector3.RIGHT


## Чаша подсвечника — ею он упирается в землю.
func _weapon_tip() -> Vector3:
	return Vector3(0.0, 1.12, 0.0)


## Подсвечник ведёт поза молота (_update_extra) и сама возвращает его после слепоты.
func _weapon_posed_by_self() -> bool:
	return kind == Kind.HEAVY


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
	if kind == Kind.HEAVY:
		if state == State.ATTACK and new_state == State.RECOVER and _move and _move.ground_impact:
			_ground_impact()
		# Удар молота прерван или не начинался (отскок от замаха героя) — подсвечник на плечо.
		if new_state != State.WINDUP and not (state in [State.WINDUP, State.ATTACK] and new_state in [State.ATTACK, State.RECOVER]):
			_move = null
	if new_state == State.WINDUP:
		match kind:
			Kind.HEAVY:
				_choose_move()
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


## Следующий удар молота: тайминги, выпад и хитбокс — из стадии подсвечника.
func _choose_move() -> void:
	_move = _moves[_move_i % _moves.size()]
	_move_i += 1
	windup_time = OVERHEAD_WINDUP if _move.ground_impact else HEAVY_WINDUP
	attack_time = _move.active_to - _move.active_from
	recover_time = _move.duration - _move.active_to + HEAVY_RECOVER_EXTRA
	attack_lunge = _move.lunge_speed * 2.0
	attack_hitbox.damage = HEAVY_DAMAGE * _move.damage_multiplier
	attack_hitbox.knockback = _move.knockback
	_attack_shape.size = Vector3(_move.hitbox_size.x, _move.hitbox_size.y, 1.2)
	_attack_shape_node.position = Vector3(_move.hitbox_offset.x, _move.hitbox_offset.y, 0.0)


## Поза подсвечника по фазе удара: замах — поднимает в начало взмаха, удар — проводит,
## потом подсвечник лежит в конце взмаха (волок) и возвращается на плечо.
func _update_extra(delta: float) -> void:
	if _prop == null:
		return
	# Ослеп и трёт глаза: подсвечник придерживает одной рукой опущенным — это делает Dummy.
	if state == State.BLINDED and arms and blind_reaction == CreatureKind.Reaction.RUB_EYES:
		return
	var rest := Vector3(CANDLESTICK.rest_blade, CANDLESTICK.rest_grip.x, CANDLESTICK.rest_grip.y)
	var target := rest
	if _move and state in [State.WINDUP, State.ATTACK, State.RECOVER]:
		var from := Vector3(_move.blade_from, _move.grip_from.x, _move.grip_from.y)
		var to := Vector3(_move.blade_to, _move.grip_to.x, _move.grip_to.y)
		match state:
			State.WINDUP:
				target = rest.lerp(from, smoothstep(0.0, windup_time, _state_time))
			State.ATTACK:
				target = from.lerp(to, ease(clampf(_state_time / maxf(attack_time, 0.01), 0.0, 1.0), 0.5))
			State.RECOVER:
				var hold := maxf(_move.recover_from - _move.active_to, 0.0)
				target = to.lerp(rest, smoothstep(hold, recover_time, _state_time))
		_pose(target.x, Vector2(target.y, target.z))
		return
	var k := 1.0 - exp(-10.0 * delta)
	var now := Vector3(_prop.rotation.z, _prop.position.x - _prop_base.x, _prop.position.y - _prop_base.y)
	var eased := now.lerp(target, k)
	_pose(eased.x, Vector2(eased.y, eased.z))


func _pose(blade: float, grip: Vector2) -> void:
	_prop.rotation = Vector3(0.0, 0.0, blade)
	_prop.position = _prop_base + Vector3(grip.x, grip.y, 0.0)


## Подсвечник ударил в пол: тряска и крошка, как у молота героя.
func _ground_impact() -> void:
	var at := global_position + Vector3(facing * (_move.hitbox_offset.x + 0.3), 0.1, 0.3)
	Events.camera_shake_requested.emit(0.3, 0.2)
	Sfx.play(&"sword_block", at, -2.0)
	HitSpark.spawn(get_parent(), at, Color(0.5, 0.48, 0.45), 16)


## Мародёр с подсвечником роняет его: первое двуручное оружие героя (один раз за игру).
func _on_died() -> void:
	super()
	if kind != Kind.HEAVY or GameState.has_flag(CANDLESTICK_FLAG):
		return
	var drop := ItemPickup.new()
	drop.name = &"CandlestickDrop"
	drop.weapon_id = &"candlestick"
	drop.flag = CANDLESTICK_FLAG
	drop.pickup_prompt = "Подобрать подсвечник"
	drop.look_size = Vector3(1.1, 0.1, 0.1)
	drop.look_color = CANDLESTICK.look_color
	# Контейнеры комнаты стоят в начале координат (Room): своё место — это место в мире.
	drop.position = Vector3(global_position.x, global_position.y, 0.0)
	get_parent().add_child.call_deferred(drop)


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
