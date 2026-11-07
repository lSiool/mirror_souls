class_name DrownedKnight
extends Dummy
## Утопленник болота (§8.9, кадр 5): старый воин, утонувший здесь много лет назад. Кости сквозь
## сгнившие доспехи, меч и щит, заросший камышом и грибами. Лежит под водой и поднимается, когда
## герой рядом. Выглядит медленным — бьёт неожиданно быстро: выпад, двойной удар, удар щитом.
## Щит держит удары спереди: пробивают только тяжёлые (удар вниз, заряженный) и удары со спины.

const RISE_RANGE := 6.0
const RISE_TIME := 1.1
const UNDERWATER := -2.4
const SHIELD_DAMAGE := 0.15
const BACKSTEP_SPEED := 6.0

enum Move { THRUST, DOUBLE, BASH }

var move := Move.THRUST
var _risen := false
var _rising := false
var _second := false
var _shield_spark := 0.0

@onready var shield: Node3D = $Visual/Shield
@onready var blade: Node3D = $Visual/Blade


func _ready() -> void:
	super()
	visual.position.y = UNDERWATER


func _wake_check(_delta: float) -> void:
	_find_player()
	if _rising or _player == null:
		return
	if absf(_player.global_position.x - global_position.x) < RISE_RANGE:
		_rise()


func _rise() -> void:
	_rising = true
	facing = signf(_player.global_position.x - global_position.x)
	visual.rotation.y = 0.0 if facing > 0.0 else PI
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Color(0.25, 0.3, 0.22), 30)
	Sfx.play(&"glass_crack", global_position, -6.0)
	var tween := create_tween()
	tween.tween_property(visual, "position:y", 0.0, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_risen = true
	_set_state(State.CHASE)


func _chase(delta: float) -> void:
	if _player and absf(_player.global_position.x - global_position.x) <= attack_range:
		var roll := randf()
		move = Move.BASH if roll < 0.25 else (Move.DOUBLE if roll < 0.65 else Move.THRUST)
		_second = false
	super(delta)


func _set_state(new_state: State) -> void:
	var next := new_state
	var quick := false
	if next == State.RECOVER and move == Move.DOUBLE and not _second:
		_second = true
		quick = true
		next = State.WINDUP
	if next == State.WINDUP:
		match move:
			Move.THRUST:
				windup_time = 0.35
				attack_lunge = 9.0
				attack_hitbox.damage = 16.0
				attack_hitbox.knockback = 5.0
			Move.DOUBLE:
				windup_time = 0.18 if quick else 0.3
				attack_lunge = 5.0
				attack_hitbox.damage = 12.0
				attack_hitbox.knockback = 4.0
			Move.BASH:
				windup_time = 0.28
				attack_lunge = 4.0
				attack_hitbox.damage = 8.0
				attack_hitbox.knockback = 11.0
		recover_time = 0.55
	super(next)


func _on_attack_ended() -> void:
	# После серии — отскок назад.
	if move == Move.DOUBLE and _second:
		velocity.x = -facing * BACKSTEP_SPEED


## Щит спереди: лёгкие удары почти не проходят.
func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD or not _risen:
		return
	var from_front := signf(hitbox.global_position.x - global_position.x) == facing
	var guarding := state not in [State.ATTACK, State.STAGGER, State.OFF_BALANCE, State.CRITICAL_HIT, State.KNOCKDOWN]
	if from_front and guarding and not hitbox.heavy:
		last_weapon = hitbox.weapon_type
		health.take_damage(hitbox.damage * SHIELD_DAMAGE)
		poise -= hitbox.poise_damage * 0.5
		_poise_delay = poise_regen_delay
		_shield_spark = 0.15
		Sfx.play(&"sword_block", global_position)
		HitSpark.spawn(get_parent(), global_position + Vector3(facing * 0.6, 1.2, 0.3), Color(1.0, 0.75, 0.4), 10)
		if poise <= 0.0:
			poise = max_poise
			_set_state(State.STAGGER)
		elif state in [State.PATROL, State.INVESTIGATE]:
			_set_state(State.CHASE)
		return
	super(hitbox)


func _update_extra(delta: float) -> void:
	_shield_spark = maxf(_shield_spark - delta, 0.0)
	var k := 1.0 - exp(-16.0 * delta)
	var shield_out := 0.25 if _shield_spark > 0.0 else 0.0
	shield.position.x = lerpf(shield.position.x, 0.45 + shield_out, k)
	var arm := 0.0
	match state:
		State.WINDUP:
			arm = 1.4 if move != Move.BASH else 0.4
		State.ATTACK:
			arm = -1.2 if move != Move.BASH else 0.0
			if move == Move.BASH:
				shield.position.x = 0.9
	blade.rotation.z = lerpf(blade.rotation.z, arm, k)
