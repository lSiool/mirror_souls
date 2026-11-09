class_name DrownedKnight
extends Dummy
## Утопленник болота (§8.9, кадр 5): старый воин, утонувший здесь много лет назад. Кости сквозь
## сгнившие доспехи, меч и щит, заросший камышом и грибами. Лежит под водой и поднимается, когда
## герой рядом. Выглядит медленным — бьёт неожиданно быстро: выпад, двойной удар, удар щитом.
## Щит держит удары спереди: пробивают только тяжёлые (удар вниз, заряженный) и удары со спины.
##
## Щит — как у щитовых скелетов Dark Souls (2026-11-09): поднят на подходе и отбивает стрелы;
## в замахе, ударе и откате опущен — откат и есть окно для атаки. Удар в щит отталкивает его,
## и он не сразу бьёт в ответ (GUARD_RECOIL). Принял GUARD_BREAK_HITS ударов подряд —
## защита пробита: потерял равновесие, можно добить, как после парирования.

const RISE_RANGE := 6.0
const RISE_TIME := 1.1
const UNDERWATER := -2.4
const SHIELD_DAMAGE := 0.15
const SHIELD_DAMAGE_CORRODED := 0.45
const BACKSTEP_SPEED := 6.0
## После удара в щит: столько секунд не начинает атаку и отъезжает назад с такой скоростью.
const GUARD_RECOIL := 0.6
const GUARD_PUSH := 2.6
## Сколько ударов подряд держит щит; счёт сбрасывается, если GUARD_FORGET секунд не били.
const GUARD_BREAK_HITS := 4
const GUARD_FORGET := 1.6
## После удара в щит иногда отвечает ударом щитом — с заметным замахом.
const BASH_REPLY_CHANCE := 0.35

enum Move { THRUST, DOUBLE, BASH }

var move := Move.THRUST
var _risen := false
var _rising := false
var _second := false
var _shield_spark := 0.0
var _guard_hits := 0
var _guard_forget := 0.0
var _guard_lock := 0.0
var _bash_reply := false

@onready var shield: Node3D = $Visual/Shield
@onready var blade: Node3D = $Visual/Blade


func _init() -> void:
	creature = CreatureKind.Kind.SKELETON
	graybox_arms = false


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
	# Принял удар на щит: прикрывается и отъезжает, в ответ — не сразу.
	if _guard_lock > 0.0:
		_brake(10.0, delta)
		return
	if _player and absf(_player.global_position.x - global_position.x) <= attack_range:
		var roll := randf()
		move = Move.BASH if roll < 0.25 else (Move.DOUBLE if roll < 0.65 else Move.THRUST)
		if _bash_reply:
			move = Move.BASH
		_bash_reply = false
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
				windup_time = 0.42
				attack_lunge = 9.0
				attack_hitbox.damage = 16.0
				attack_hitbox.knockback = 5.0
				recover_time = 0.9
			Move.DOUBLE:
				windup_time = 0.22 if quick else 0.36
				attack_lunge = 5.0
				attack_hitbox.damage = 12.0
				attack_hitbox.knockback = 4.0
				recover_time = 0.85
			Move.BASH:
				windup_time = 0.42
				attack_lunge = 4.0
				attack_hitbox.damage = 8.0
				attack_hitbox.knockback = 11.0
				recover_time = 0.7
	super(next)


func _on_attack_ended() -> void:
	# После серии — отскок назад.
	if move == Move.DOUBLE and _second:
		velocity.x = -facing * BACKSTEP_SPEED


## Щит поднят: на подходе и пока прикрывается после удара в щит. В замахе, ударе и откате — опущен.
func guarding() -> bool:
	return _risen and state in [State.PATROL, State.CHASE, State.INVESTIGATE]


## Щит спереди: лёгкие удары почти не проходят, но толкают его и копят пробитие защиты.
func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD or not _risen:
		return
	var from_front := signf(hitbox.global_position.x - global_position.x) == facing
	if from_front and guarding() and not hitbox.heavy:
		_on_blocked(hitbox)
		return
	super(hitbox)


func _on_blocked(hitbox: Hitbox) -> void:
	last_weapon = hitbox.weapon_type
	# Кислота разъела щит: пропускает больше (§6.2).
	var through := SHIELD_DAMAGE_CORRODED if statuses.has(Statuses.CORRODED) else SHIELD_DAMAGE
	health.take_damage(hitbox.damage * through)
	_shield_spark = 0.18
	_jolt = JOLT_TIME
	velocity.x = -facing * GUARD_PUSH
	Sfx.play(&"sword_block", global_position)
	HitSpark.spawn(get_parent(), global_position + Vector3(facing * 0.6, 1.2, 0.3), Color(1.0, 0.75, 0.4), 10)
	if hitbox.weapon_type == &"bow":
		# Стрелы щит просто отбивает — ни отката, ни пробития.
		return
	_guard_hits += 1
	_guard_forget = GUARD_FORGET
	_guard_lock = GUARD_RECOIL
	if _guard_hits >= GUARD_BREAK_HITS:
		_guard_hits = 0
		_guard_lock = 0.0
		HitSpark.spawn(get_parent(), global_position + Vector3(facing * 0.5, 1.3, 0.3), OFF_BALANCE_COLOR, 24)
		Sfx.play(&"sword_parry", global_position, -4.0)
		_set_state(State.OFF_BALANCE)
		return
	_bash_reply = randf() < BASH_REPLY_CHANCE
	if state in [State.PATROL, State.INVESTIGATE]:
		_set_state(State.CHASE)


func _update_extra(delta: float) -> void:
	_shield_spark = maxf(_shield_spark - delta, 0.0)
	_guard_lock = maxf(_guard_lock - delta, 0.0)
	_guard_forget = maxf(_guard_forget - delta, 0.0)
	if _guard_forget <= 0.0:
		_guard_hits = 0
	var k := 1.0 - exp(-16.0 * delta)
	# Щит поднят — перед телом; опущен — у бедра, тело открыто.
	var shield_out := 0.25 if _shield_spark > 0.0 else 0.0
	var raised := guarding() or state == State.FLINCH
	shield.position.x = lerpf(shield.position.x, (0.45 if raised else 0.15) + shield_out, k)
	shield.position.y = lerpf(shield.position.y, 1.15 if raised else 0.8, k)
	var arm := 0.0
	match state:
		State.WINDUP:
			arm = 1.4 if move != Move.BASH else 0.4
		State.ATTACK:
			arm = -1.2 if move != Move.BASH else 0.0
			if move == Move.BASH:
				shield.position.x = 0.9
	blade.rotation.z = lerpf(blade.rotation.z, arm, k)
