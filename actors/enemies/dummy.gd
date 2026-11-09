class_name Dummy
extends CharacterBody3D
## Враг-болванка для прототипа: патруль → заметил → телеграф → удар → откат.
## Удар можно прочитать: перед атакой тело наливается красным (§1.1, читаемый бой).
##
## Свойства типа врага — обязательные вопросы при создании нового врага (§6.3):
## стойкость, время разворота, поддаётся ли удару в спину, можно ли парировать,
## с какого удара осекается и держит ли удар в собственном замахе.
##
## Реакция на удар героя — по тяжести, как в Dark Souls (§6.3, 2026-11-09):
## - любой удар — вздрог: тело дёргается назад, враг не прерывается;
## - удар не слабее flinch_threshold (по стойкости) — осечка: шаг назад, замах сбит;
##   в замахе и ударе (WINDUP, ATTACK) при armored_attack — только вздрог: начатую атаку
##   одиночный удар не сбивает, размен ударами; окно — подход и откат;
## - стойкость сломана — ошеломлён (STAGGER), отлетает;
## - тяжёлый удар не слабее KNOCKDOWN_POISE по сломанной стойкости — сбит с ног.
##
## Общие эффекты (§6.2, §6.3, 2026-11-09) — слепота и будущие — каждый класс врага (creature,
## CreatureKind) переживает по-своему. Слепой враг (BLINDED) не нападает и не видит героя;
## удары его не выводят из слепоты. Гуманоид отшатывается и трёт глаза, вампир шатается — его
## можно добить спереди. Свою реакцию наследник рисует сам (Werewolf, Rat, FogWraith).

enum State {
	DORMANT, PATROL, CHASE, WINDUP, ATTACK, RECOVER, STAGGER,
	OFF_BALANCE, CRITICAL_HIT, KNOCKDOWN, DEAD, INVESTIGATE, FLINCH, BLINDED,
}

const WINDUP_COLOR := Color(1.0, 0.35, 0.1)
const BLEED_COLOR := Color(0.65, 0.05, 0.05)
const BLEED_FULL := 100.0
## Какая доля всего здоровья уходит, когда кровотечение вырвалось.
const BLEED_BURST := 0.2
## Сколько секунд без ударов оно держится и как быстро потом спадает.
const BLEED_HOLD := 2.0
const BLEED_FADE := 20.0
const OFF_BALANCE_COLOR := Color(1.0, 0.85, 0.2)
const HEAD_SLIDE_SPEED := 5.0
## Страховка: если добивание так и не пришло, враг освобождается сам.
const CRITICAL_TIMEOUT := 2.0
## Тяжёлый удар с такой силой по стойкости, сломав её, сбивает с ног (заряд, молот сверху).
const KNOCKDOWN_POISE := 50.0
## Тело в атаке (§6.1, 2026-11-09): в замахе отклоняется назад и к WINDUP_PEAK замирает наверху —
## пауза перед ударом читается; удар — рывок вперёд, в откате тело возвращается.
const WINDUP_LEAN := 0.2
const WINDUP_PEAK := 0.75
const STRIKE_LEAN := -0.28
## Вздрог: сколько секунд тело дёргается и насколько отклоняется.
const JOLT_TIME := 0.14
const JOLT_TILT := 0.22
## Слепота (§6.2): каждое следующее ослепление за бой короче (привыкание, ×BLIND_HABIT);
## через BLIND_FORGET секунд без слепоты враг это забывает. Вышло короче BLIND_MIN — уже
## не слепнет, только вздрогнул.
const BLIND_HABIT := 0.6
const BLIND_FORGET := 20.0
const BLIND_MIN := 0.5
## Первая четверть слепоты — отшатнулся (у стандартной слепоты — секунда), дальше трёт глаза.
const BLIND_RECOIL_SHARE := 0.25
const BLIND_STEP_BACK := 2.5

## Кто он для мастерства оружия героя. Кто из врагов мини-босс — решим позже; пока босс один — Кузнец.
enum Rank { COMMON, MINIBOSS, BOSS }
const MASTERY_POINTS := {Rank.COMMON: 1.0, Rank.MINIBOSS: 2.0, Rank.BOSS: 5.0}

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
## Ошеломлён после сломанной стойкости: окно на пару ударов (§6, по ориентиру NRFTW, 2026-11-09).
@export var stagger_time := 0.9
@export var gravity := 30.0
## Рывок вперёд в момент удара.
@export var attack_lunge := 5.0
@export var body_color := Color(0.42, 0.4, 0.44)
## Насколько тело разгорается в замахе; у кого замах виден по оружию, тому меньше.
@export_range(0.0, 1.0) var windup_tint := 1.0

@export_group("Свойства типа врага")
## Запас стойкости: удары его снижают, при нуле — стаггер.
@export var max_poise := 50.0
@export var poise_regen := 25.0
@export var poise_regen_delay := 1.2
## Сколько секунд враг разворачивается. Медленный разворот — шанс ударить в спину.
@export var turn_time := 0.4
@export var backstab_allowed := true
@export var parry_allowed := true
## Перекат героя проходит сквозь него и выводит на другую сторону; в остальное время тело твёрдое.
## С 2026-11-09 — у любого врага (§6.3); выключать только тому, кто сам как стена.
@export var roll_through := true
@export var off_balance_time := 1.5
@export var knockdown_time := 0.8
## С какой силы удара (по стойкости) враг осекается; 0 — от любого (крыса), 999 — никогда (босс).
## Меч бьёт 18–26, выпад 40, заряд и молот сверху 55–80.
@export var flinch_threshold := 15.0
@export var flinch_time := 0.28
## В собственном замахе и ударе не осекается — только вздрагивает: размен ударами.
@export var armored_attack := true
## Особое добивание этого врага. Пусто — герой бьёт добиванием своего оружия.
@export var riposte_step: AttackStep
## Голос врага (события Sfx) поверх звука удара и падения. Пусто — безголосый (стекло, механизм).
@export var hurt_voice: StringName = &"enemy_hurt_voice"
@export var death_voice: StringName = &"enemy_death_voice"
## Сколько отзвуков прошлого остаётся после врага (летят к герою сами).
@export var echoes := 30
## Очки мастерства за него: обычный враг — 1, мини-босс — 2, босс — 5.
@export var rank := Rank.COMMON
## Чем он сражается: герой, побеждая его, понемногу учится этому оружию. Пусто — когти, тело, клыки.
@export var weapon_type: StringName
## Кровоточит ли: у стекла и механизмов крови нет.
@export var can_bleed := true
## Нежить или нечисть: святая склянка бьёт её во много раз сильнее (§6.2).
@export var unholy := false

@export_group("Класс и сопротивления")
## Базовый класс (§6.3): от него зависит, как враг переживает общие эффекты — слепоту и будущие.
## Свой класс наследник ставит в _init, сцена может его переопределить.
@export var creature := CreatureKind.Kind.HUMAN
## Сопротивление слепоте 0…1: настолько короче слепота (Кузнец — 0.5, вдвое).
@export_range(0.0, 1.0) var blind_resistance := 0.0
## Руки-капсулы graybox у гуманоида (до моделей): держат оружие, трут глаза.
@export var graybox_arms := true

@export_group("Облик")
## Манекен героя вместо примитивов (EnemyModel, §3.3): &"soldier", &"vampire". Пусто — graybox.
@export var mannequin_look: StringName

## Остаётся в мире статуей (босс): комната не забывает его как убитого, его хранит флаг босса.
var leaves_statue := false
## Чьё оружие нанесло последний удар; пусто — не герой (ловушка, падение).
var last_weapon: StringName
## Накопленное кровотечение 0…100: полное — рывок крови и доля здоровья. Без ударов спадает.
var bleed := 0.0
var _bleed_delay := 0.0
## Красная вспышка, когда кровотечение вырвалось: поверх белой вспышки удара.
var _bleed_flash := 0.0
## Яд, огонь, кислота, смола, слепота (§6.2).
var statuses: Statuses
## Как враг переживает нынешнюю слепоту (по классу, CreatureKind).
var blind_reaction := CreatureKind.Reaction.IMMUNE
## Руки graybox; null — не гуманоид или руки свои (оборотень, Утопленник, манекен).
var arms: GrayboxArms
## Манекен героя в облике врага; null — graybox.
var model: EnemyModel

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
var _jolt := 0.0
## Сколько раз ослеплён за бой и сколько ещё помнит об этом.
var _blind_count := 0
var _blind_forget := 0.0
## Сколько секунд от начала слепоты длится отшатывание.
var _blind_recoil := 0.0
## Глаза в пространстве Visual: к ним тянутся руки в слепоте.
var _eye_point := Vector3.ZERO
## Оружие в руке (узел прямо под Visual) и его место: в слепоте его несёт кисть, потом оно возвращается.
var _grip: Node3D
var _grip_rest := Vector3.ZERO
var _grip_rest_angle := 0.0
var _grip_return := 0.0

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
	statuses = Statuses.new(health, body_height())
	statuses.resist = _resist_status
	add_child(statuses)
	statuses.started.connect(_on_status_started)
	statuses.ended.connect(_on_status_ended)
	_eye_point = _find_eye_point()
	if mannequin_look != &"":
		model = EnemyModel.build(self, visual, _material, mannequin_look)
		# Примитивы остаются для чисел (рост, наклон), но не видны.
		body_mesh.visible = false
		var eye := visual.get_node_or_null(^"Eye") as Node3D
		if eye:
			eye.visible = false
	elif graybox_arms and CreatureKind.humanoid(creature):
		arms = GrayboxArms.build(visual, body_mesh, _material)
		_grip = _grip_node()
		if _grip:
			_grip_rest = _grip.position
			_grip_rest_angle = _grip.rotation.z
		# Оружие в руке с первого кадра.
		_update_arms(0.0)
	Events.noise_made.connect(_on_noise)
	state = State.DORMANT if dormant else State.PATROL


func mastery_points() -> float:
	return MASTERY_POINTS[rank]


## Половина ширины тела: докуда герой ещё внутри него.
func body_half_width() -> float:
	var shape := ($Collision as CollisionShape3D).shape
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.x * 0.5
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	return 0.5


## Рост тела: где на нём горит пламя и откуда капает смола.
func body_height() -> float:
	var shape := ($Collision as CollisionShape3D).shape
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height
	return 1.8


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
		# Спящий (в засаде, на камне) тоже держит оружие в руке.
		_update_arms(delta)
		return
	# В смоле всё медленнее: и шаг, и замах, и откат.
	_state_time += delta * statuses.time_mult()
	_find_player()
	_regen_poise(delta)
	_forget_blindness(delta)
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
		State.FLINCH:
			_brake(18.0, delta)
			if _state_time >= flinch_time:
				_set_state(State.CHASE)
		State.BLINDED:
			# Слепой не нападает и не ищет героя; выходит из слепоты, когда она кончится.
			_brake(10.0, delta)
		State.DEAD:
			_brake(25.0, delta)
	if _head_slide != 0.0:
		velocity.x = _head_slide * HEAD_SLIDE_SPEED
	velocity.z = 0.0
	_move_slowed()
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
	_update_arms(delta)
	if model:
		model.update(delta)


## Шаг с учётом смолы: скорость гасится только на сам шаг, падение — как обычно.
func _move_slowed() -> void:
	var mult := statuses.speed_mult()
	velocity.x *= mult
	move_and_slide()
	velocity.x /= mult


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


## Как этот враг переживает эффект: по классу (CreatureKind). Свой случай — переопределить.
func _status_reaction(id: StringName) -> CreatureKind.Reaction:
	return CreatureKind.reaction(id, creature)


## Враг ослеп (BLINDED уже стоит): голос, звук — у наследника.
func _on_blinded() -> void:
	pass


## Оружие в руке graybox-гуманоида: узел прямо под Visual. Нет — руки свободны.
## Держит его рука того же бока (правая — +Z).
func _grip_node() -> Node3D:
	return null


## Где оружие держат кисти, в пространстве оружия: первая — держащая рука,
## вторая (у двуручного) — выше по древку.
func _grip_points() -> Array[Vector3]:
	return [Vector3.ZERO]


## Вдоль чего лежит оружие (от рукояти к острию) в пространстве оружия.
func _weapon_axis() -> Vector3:
	return Vector3.UP


## Двуручное в слепоте: угол, под которым его придерживают одной рукой опущенным.
func _blind_weapon_angle() -> float:
	return -2.85


## Конец оружия (в пространстве оружия): им опущенное двуручное упирается в землю.
func _weapon_tip() -> Vector3:
	return Vector3(0.0, 1.0, 0.0)


## Позу оружия ведёт сам наследник (и возвращает его после слепоты).
func _weapon_posed_by_self() -> bool:
	return false


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


## Добивание спереди: после парирования, а вампира — и в слепоте (§6.2).
func can_be_riposted() -> bool:
	if state == State.BLINDED:
		return blind_reaction == CreatureKind.Reaction.DISORIENT
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


# --- Слепота: общий эффект, реакция по классу (§6.2, §6.3) ------------------

## Сколько секунд слепота на самом деле держит этого врага; 0 — не подействовала.
## Источник вешает стандартную (Statuses.BLIND_TIME), здесь — класс, сопротивление, привыкание.
func _resist_status(id: StringName, time: float) -> float:
	if id != Statuses.BLIND:
		return time
	# Спящий, в сцене, на клинке героя и мёртвый не слепнет.
	if state in [State.DORMANT, State.DEAD, State.CRITICAL_HIT]:
		return 0.0
	if _status_reaction(id) == CreatureKind.Reaction.IMMUNE:
		return 0.0
	# Продление начавшейся слепоты — без нового привыкания.
	var fresh := not statuses.has(id)
	var habit := pow(BLIND_HABIT, _blind_count - (0 if fresh else 1))
	var left := time * CreatureKind.duration_scale(id, creature) * (1.0 - blind_resistance) * habit
	if fresh:
		_blind_count += 1
	_blind_forget = BLIND_FORGET
	if left < BLIND_MIN:
		# Привык: свет только резанул.
		_jolt = JOLT_TIME
		return 0.0
	return left


func _forget_blindness(delta: float) -> void:
	if _blind_count == 0 or statuses.has(Statuses.BLIND):
		return
	_blind_forget -= delta
	if _blind_forget <= 0.0:
		_blind_count = 0


func _on_status_started(id: StringName) -> void:
	if id != Statuses.BLIND:
		return
	blind_reaction = _status_reaction(id)
	_blind_recoil = statuses.time_left(id) * BLIND_RECOIL_SHARE
	_turn_t = -1.0
	# Отшатнулся: шаг назад от света.
	if blind_reaction in [CreatureKind.Reaction.RUB_EYES, CreatureKind.Reaction.SHAKE_HEAD]:
		velocity.x = -facing * BLIND_STEP_BACK
	_set_state(State.BLINDED)
	_on_blinded()


func _on_status_ended(id: StringName) -> void:
	if id == Statuses.BLIND and state == State.BLINDED:
		_set_state(State.CHASE)


## Ещё отшатывается (начало слепоты), а не трёт глаза.
func blind_recoiling() -> bool:
	return state == State.BLINDED and _state_time < _blind_recoil


## Руки graybox (§6.3, 2026-11-09). Правило: оружие всегда в руке — не дотянулась кисть до
## рукояти, рукоять подтягивается к кисти. В слепоте одноручное оружие ложится вдоль
## предплечья, а обе кисти трут глаза; двуручное придерживается одной рукой опущенным,
## другая трёт глаза.
func _update_arms(delta: float) -> void:
	if arms == null:
		return
	var t := _state_time
	var rubbing := state == State.BLINDED and blind_reaction == CreatureKind.Reaction.RUB_EYES
	var eye := _eye_point + Vector3(0.1, 0.0, 0.0)
	# Ладони к глазам рывком, потом кисти ходят по кругу вразнобой.
	var rub := Vector3(cos(t * 9.0) * 0.03, sin(t * 9.0) * 0.05, 0.0)
	if blind_recoiling():
		rub = Vector3(0.06, 0.03, 0.0)
	if _grip == null:
		_update_free_arms(delta, rubbing, eye, rub)
		return
	var points := _grip_points()
	var main := arms.arm_at(_grip.position)
	var off := arms.other(main)
	if rubbing:
		if points.size() > 1:
			# Двуручное: одна рука держит его опущенным, конец упирается в землю; другая трёт глаза.
			var lowered := _blind_weapon_angle()
			var down := Basis(Vector3.BACK, lowered) * (_weapon_tip() - points[0])
			arms.reach(off, eye + rub, delta, 16.0)
			arms.reach(main, Vector3(main.position.x + arms.length * 0.3, -down.y, main.position.z), delta, 10.0)
			_grip.rotation.z = lerp_angle(_grip.rotation.z, lowered, 1.0 - exp(-8.0 * delta))
		else:
			# Одноручное: обе кисти у глаз, оружие вдоль предплечья.
			arms.reach(main, eye + rub, delta, 16.0)
			arms.reach(off, eye - rub, delta, 16.0)
			var along := _angle_of(arms.forearm(main)) - _angle_of(_weapon_axis())
			_grip.rotation.z = lerp_angle(_grip.rotation.z, along, 1.0 - exp(-14.0 * delta))
		_attach_grip(main, points[0], main.position.z)
		return
	if _grip_return > 0.0 and not _weapon_posed_by_self():
		# Слепота прошла: оружие возвращается на место (кисть не отпускает рукоять).
		_grip_return -= delta
		var k := 1.0 - exp(-10.0 * delta)
		_grip.position = _grip.position.lerp(_grip_rest, k)
		if points.size() == 1:
			_grip.rotation.z = lerp_angle(_grip.rotation.z, _grip_rest_angle, k)
	arms.hold(main, _grip_point(points[0]))
	_attach_grip(main, points[0], _grip.position.z)
	if state == State.BLINDED and blind_reaction == CreatureKind.Reaction.DISORIENT:
		# Свободной рукой ловит равновесие.
		arms.swing(off, -0.9 + sin(t * 4.5 + 1.3) * 0.4, delta, 6.0)
	elif points.size() > 1:
		# Вторая кисть — выше по древку.
		arms.hold(off, _grip_point(points[1]))
	else:
		arms.swing(off, -0.1, delta)


## Руки без оружия (кулаки): трут глаза, ловят равновесие, в замахе отводят кулак.
func _update_free_arms(delta: float, rubbing: bool, eye: Vector3, rub: Vector3) -> void:
	if rubbing:
		arms.reach(arms.right, eye + rub, delta, 16.0)
		arms.reach(arms.left, eye - rub, delta, 16.0)
		return
	var t := _state_time
	if state == State.BLINDED and blind_reaction == CreatureKind.Reaction.DISORIENT:
		arms.swing(arms.right, 1.1 + sin(t * 4.5) * 0.4, delta, 6.0)
		arms.swing(arms.left, -0.9 + sin(t * 4.5 + 1.3) * 0.4, delta, 6.0)
		return
	match state:
		State.WINDUP:
			arms.swing(arms.right, -1.0, delta, 8.0)
			arms.swing(arms.left, 0.3, delta, 8.0)
		State.ATTACK:
			arms.swing(arms.right, 1.6, delta, 30.0)
			arms.swing(arms.left, -0.3, delta, 30.0)
		_:
			arms.swing(arms.right, 0.12, delta)
			arms.swing(arms.left, -0.08, delta)


## Точка хвата оружия (в пространстве оружия) — в пространстве Visual.
func _grip_point(local: Vector3) -> Vector3:
	return _grip.position + _grip.basis * local


## Оружие к кисти: точка хвата ложится в кисть, оружие на глубине z.
func _attach_grip(arm: Node3D, local: Vector3, z: float) -> void:
	var gap := arms.hand(arm) - _grip_point(local)
	_grip.position = Vector3(_grip.position.x + gap.x, _grip.position.y + gap.y, z)


## Насколько рукоять оружия разошлась с держащей её кистью (в плоскости кадра); 0 — в руке.
## Для тестов: правило «оружие всегда в руке».
func weapon_gap() -> float:
	if arms == null or _grip == null:
		return 0.0
	var gap := arms.hand(arms.arm_at(_grip.position)) - _grip_point(_grip_points()[0])
	return Vector2(gap.x, gap.y).length()


static func _angle_of(v: Vector3) -> float:
	return atan2(v.y, v.x)


## Глаза в пространстве Visual: узел глаза, иначе лицевая сторона головы, иначе макушка.
func _find_eye_point() -> Vector3:
	for path: NodePath in [^"Head/EyeA", ^"EyeA", ^"Eye", ^"Head/Eye"]:
		var eye := visual.get_node_or_null(path) as Node3D
		if eye:
			return _in_visual(eye)
	var head := visual.get_node_or_null(^"Head") as Node3D
	if head:
		var front := 0.0
		if head is MeshInstance3D and (head as MeshInstance3D).mesh is BoxMesh:
			front = ((head as MeshInstance3D).mesh as BoxMesh).size.x * 0.5
		return _in_visual(head) + Vector3(front, 0.03, 0.0)
	return Vector3(0.2, body_height(), 0.0)


func _in_visual(node: Node3D) -> Vector3:
	var at := Vector3.ZERO
	var current := node
	while current and current != visual:
		at = current.transform * at
		current = current.get_parent() as Node3D
	return at


# --- Попадания --------------------------------------------------------------

func _on_hurt(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	last_weapon = hitbox.weapon_type
	health.take_damage(hitbox.damage)
	_flash = 0.12
	if health.is_dead():
		return
	_add_bleed(hitbox.bleed)
	if health.is_dead():
		return
	Sfx.play(&"enemy_hurt", global_position)
	Sfx.play(hurt_voice, global_position)
	# Слепого удар не будит: только вздрагивает.
	if state == State.BLINDED:
		_jolt = JOLT_TIME
		return
	# В уязвимых состояниях реакции нет: враг и так беззащитен.
	if state in [State.CRITICAL_HIT, State.KNOCKDOWN, State.OFF_BALANCE]:
		return
	var force := hitbox.poise_damage * statuses.poise_mult()
	poise -= force
	_poise_delay = poise_regen_delay
	var dir := hitbox.knockback_direction(self)
	_jolt = JOLT_TIME
	if poise <= 0.0:
		# Стойкость сломана — направленный стаггер, враг разворачивается к обидчику;
		# очень тяжёлый удар сбивает с ног.
		poise = max_poise
		velocity.x = dir.x * hitbox.knockback
		velocity.y = 3.0 if hitbox.heavy else 1.5
		facing = -dir.x
		_turn_t = -1.0
		# Боссов с ног не сбить: у них свои стаггеры.
		var floored := hitbox.heavy and force >= KNOCKDOWN_POISE and rank != Rank.BOSS
		_set_state(State.KNOCKDOWN if floored else State.STAGGER)
	elif force >= flinch_threshold and not (armored_attack and state in [State.WINDUP, State.ATTACK]):
		# Осечка: шаг назад, замах сбит; враг повернулся к обидчику.
		velocity.x = dir.x * hitbox.knockback * 0.45
		facing = -dir.x
		_turn_t = -1.0
		_set_state(State.FLINCH)
	else:
		# Вздрог: удар почувствовал, но не прервался. Чуть подался назад.
		if state != State.ATTACK:
			velocity.x += dir.x * minf(hitbox.knockback * 0.2, 1.2)
		if state in [State.PATROL, State.INVESTIGATE]:
			# Удар не сбил, но враг заметил героя.
			_set_state(State.CHASE)


## Копим кровотечение; полное вырывается: доля от всего здоровья, сильным врагам больнее.
func _add_bleed(amount: float) -> void:
	if amount <= 0.0 or not can_bleed:
		return
	_bleed_delay = BLEED_HOLD
	bleed += amount
	if bleed < BLEED_FULL:
		return
	bleed = 0.0
	_bleed_flash = 0.35
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 1.1, 0.3), BLEED_COLOR, 34)
	Sfx.play(&"critical_pierce", global_position, -4.0)
	health.take_damage(health.max_health * BLEED_BURST)


func _on_died() -> void:
	_set_state(State.DEAD)
	statuses.clear()
	Sfx.play(&"enemy_death", global_position)
	Sfx.play(death_voice, global_position)
	Events.enemy_killed.emit(self)
	collision_layer = 0
	# Мёртвого не толкают: только мир.
	collision_mask = 1
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
	var was_blind := state == State.BLINDED
	state = new_state
	_state_time = 0.0
	# Из слепоты вывели раньше (добивание, сцена босса, смерть) — слепота снята.
	if was_blind and new_state != State.BLINDED:
		statuses.remove(Statuses.BLIND)
		_grip_return = 0.5


## Поза: потерял равновесие — качается назад, сбит с ног — лежит.
func _update_pose(delta: float) -> void:
	var tilt := 0.0
	var rate := 12.0
	match state:
		State.WINDUP:
			# Наверху замаха тело замирает и чуть дрожит от напряжения.
			var k := clampf(_state_time / (windup_time * WINDUP_PEAK), 0.0, 1.0)
			tilt = WINDUP_LEAN * smoothstep(0.0, 1.0, k)
			if k >= 1.0:
				tilt += sin(_state_time * 60.0) * 0.012
		State.ATTACK:
			tilt = STRIKE_LEAN
			rate = 40.0
		State.RECOVER:
			tilt = STRIKE_LEAN * (1.0 - smoothstep(0.0, 1.0, _state_time / maxf(recover_time * 0.6, 0.01)))
		State.STAGGER:
			# Ошеломлён: откинулся назад и шатается.
			tilt = 0.3 + sin(_state_time * 9.0) * 0.06
		State.OFF_BALANCE:
			tilt = 0.35 + sin(_state_time * 14.0) * 0.08
		State.CRITICAL_HIT:
			tilt = 0.25
		State.KNOCKDOWN:
			tilt = PI * 0.5
		State.FLINCH:
			tilt = 0.3 * (1.0 - clampf(_state_time / flinch_time, 0.0, 1.0))
		State.BLINDED:
			match blind_reaction:
				CreatureKind.Reaction.RUB_EYES:
					if blind_recoiling():
						# Отшатнулся от света — резко назад.
						tilt = 0.38
						rate = 20.0
					else:
						# Ссутулился и трёт глаза, покачиваясь.
						tilt = -0.14 + sin(_state_time * 3.0) * 0.04
						rate = 6.0
				CreatureKind.Reaction.DISORIENT:
					# Шатается: потерял, где верх и где герой.
					tilt = 0.18 + sin(_state_time * 4.5) * 0.16
					rate = 8.0
	# Вздрог поверх позы: резкий толчок назад и быстрый возврат.
	if _jolt > 0.0:
		_jolt = maxf(_jolt - delta, 0.0)
		tilt += JOLT_TILT * sin(_jolt / JOLT_TIME * PI)
		body_mesh.rotation.z = tilt
		return
	body_mesh.rotation.z = lerpf(body_mesh.rotation.z, tilt, 1.0 - exp(-rate * delta))


func _update_material(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_bleed_delay = maxf(_bleed_delay - delta, 0.0)
	if _bleed_delay <= 0.0:
		bleed = maxf(bleed - BLEED_FADE * delta, 0.0)
	# Копится кровотечение — тело темнеет кровью.
	var color := statuses.tint(body_color.lerp(BLEED_COLOR, bleed / BLEED_FULL * 0.7))
	var glow := statuses.glow()
	if state == State.WINDUP:
		var t := clampf(_state_time / windup_time, 0.0, 1.0)
		color = body_color.lerp(WINDUP_COLOR, t * windup_tint)
		glow = t * 1.5 * windup_tint
	elif state == State.OFF_BALANCE or (state == State.BLINDED and blind_reaction == CreatureKind.Reaction.DISORIENT):
		# Открыт для добивания: тот же язык, что после парирования.
		var pulse := 0.5 + 0.5 * sin(_state_time * 18.0)
		color = body_color.lerp(OFF_BALANCE_COLOR, 0.6 + 0.4 * pulse)
		glow = 0.8 + pulse
	if _flash > 0.0:
		color = Color(1.0, 1.0, 1.0, body_color.a)
		glow = 2.0
	if _bleed_flash > 0.0:
		_bleed_flash = maxf(_bleed_flash - delta, 0.0)
		color = BLEED_COLOR
		glow = 3.0
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = glow
