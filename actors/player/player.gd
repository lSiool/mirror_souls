class_name Player
extends CharacterBody3D
## Герой: движение в плоскости XY, перекат, меч, удар вниз, скольжение и лазание по стеклу,
## блок и парирование, добивание и удар в спину, лук, броски расходников из крестовины (§8.12).
## Все числа скорости и урона берутся из PlayerStats, который зависит от возраста (§1.3).

signal died
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal attack_step_started(step: AttackStep, index: int, total: int)
signal arrow_fired(arrow: Arrow)
signal item_thrown(thrown: Thrown)
signal flasks_changed(current: int, maximum: int)
## Кувырку не хватило выносливости.
signal stamina_short
## Баффы и дебаффы изменились (§8.12): HUD перерисовывает значки.
signal effects_changed

enum State {
	MOVE, ROLL, ATTACK, PLUNGE, SLIDE, CLIMB, HURT, DEAD, BLOCK, GUARD_BROKEN, CRITICAL, BOW,
	LEDGE_HANG, LEDGE_CLIMB, DRINK, CHARGE, LADDER, THROW,
}

## С какой скоростью выдавливает из босса, если перекат сорвали внутри него.
const THROUGH_PUSH := 4.0
const KILL_Y := -15.0
## Бой: враг ближе этого (по X) в боевом состоянии, или героя били / он бил недавно.
const COMBAT_RANGE := 16.0
const COMBAT_LINGER := 3.0
const COMBAT_STATES: Array[Dummy.State] = [Dummy.State.CHASE, Dummy.State.WINDUP, Dummy.State.ATTACK,
	Dummy.State.RECOVER, Dummy.State.STAGGER, Dummy.State.OFF_BALANCE, Dummy.State.KNOCKDOWN]
## Грязь (MudZone): медленнее ходит, ниже прыгает, кувырок короче и в бою дороже.
const MUD_SPEED := 0.55
const MUD_JUMP := 0.8
const MUD_ROLL_SPEED := 0.6
const MUD_ROLL_COST := 1.8
## Смола (§6.2) держит сильнее грязи; у врагов — ещё сильнее (Statuses.TAR_SPEED).
const TAR_SPEED := 0.35
const TAR_JUMP := 0.6
const TAR_ROLL_SPEED := 0.45
const TAR_ROLL_COST := 2.2
## Бросок с задержкой (§6.2): держишь ячейку — рука отводится дальше, заряд копится столько секунд.
const THROW_CHARGE_TIME := 0.3
## Смена набора оружия I/II (§8.12): сколько секунд после неё нельзя ударить — оружие ещё в пути.
const SWAP_TIME := 0.35
## Сколько добавляет к лечению одно улучшение зелья (Травница).
const FLASK_POTENCY_STEP := 0.15
const PLUNGE_LAND_TIME := 0.15
## Блок щитом дешевле блока оружием (§6.2).
const SHIELD_BLOCK_MULT := 0.6
## Вес щита и лука для веса снаряжения (§8.6).
const SHIELD_WEIGHT := 3.0
const BOW_WEIGHT := 1.5
## Удар выдержан стойкостью: короткая неуязвимость, чтобы тот же замах не бил дважды.
const POISE_IFRAMES := 0.2
const HURT_TIME := 0.3
const SLIDE_LEAN := 0.35
## С какой скоростью герой соскальзывает с головы врага: на врагах не стоят.
const HEAD_SLIDE_SPEED := 5.0
## На каком расстоянии герой встаёт к врагу для добивания и удара в спину.
const CRITICAL_DISTANCE := 1.0
## На какое натяжение подогнан банк bow_draw (tools/sound/make_candidates.py, BOW_DRAW_TIME).
## Лук натягивается быстрее или медленнее — звук ускоряется или замедляется (в пределах ±25 %).
const BOW_DRAW_SOUND_TIME := 0.6
## Прыжок с усилием — с голосом: с разгона быстрее бега (доля move_speed) или когда выносливости
## меньше этой доли. Ещё — сразу после кувырка и от стрелы-колышка. Обычный прыжок — только толчок.
const EFFORT_SPEED := 1.15
const EFFORT_STAMINA := 0.3
## Лук — на высоте плеча; стрела появляется на этом расстоянии от плеча по линии прицела.
const BOW_HEIGHT := 1.3
const BOW_REACH := 0.55
## Бросок (§6.2): с плеча, на ходу медленнее; с «вверх» — круче на столько градусов.
const THROW_HEIGHT := 1.35
const THROW_REACH := 0.45
const THROW_MOVE_MULT := 0.5
const THROW_UP_ANGLE := 20.0
## Геймпад: держать кнопку расходников и нажать крестовину — кнопка крестовины → ячейка
## (верх, лево, право, низ — как клавиши 1–4).
## Короче — тап правого курка: бросок без заряда.
const PAD_TAP := 0.2
const QUICK_PAD := {JOY_BUTTON_DPAD_UP: 0, JOY_BUTTON_DPAD_LEFT: 1, JOY_BUTTON_DPAD_RIGHT: 2, JOY_BUTTON_DPAD_DOWN: 3}

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
## Капсула: вспышки и поза смерти. С моделью невидима камере, но считает позы для логики.
var body: PlayerBody
## Манекен-гуманоид с анимациями (§3.3): только показывает.
var model: HeroModel

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
## Удар о пол этой стадии уже прозвучал.
var _impact_done := false
var _roll_dir := 1.0
var _roll_speed := 0.0
var _plunge_landed_at := -1.0
## Окно парирования: сколько ещё секунд после нажатия блока удар будет парирован.
var _parry_t := 0.0
## Сколько секунд прошло после выхода из скольжения и после кувырка (для особых ударов).
var _since_slide := 99.0
var _since_roll := 99.0
var _roll_attack_queued := false
## Враги, сквозь которых сейчас катимся (Dummy.roll_through). Твёрдыми становятся, когда вышли из них.
var _rolled_through := []
var _critical_target: Dummy
var _critical_done := false
var _critical_pierced := false
var _critical_holding := false
var _death_landed := false
var _death_dir := 1.0
var _shoot_buffer := 0.0
var _heal_buffer := 0.0
## Нажата ячейка крестовины: буфер и номер ячейки 0…3.
var _quick_buffer := 0.0
var _quick_slot := -1
## Что бросаем сейчас, вылетело ли уже и заглушка в руке.
var _throw_item: ConsumableData
var _thrown := false
var _throw_hand: MeshInstance3D
## Заряд броска 0…1 и закончен ли он (отпустили ячейку или заряд полный).
var throw_charge := 0.0
var _charge_done := false
## Яд, огонь, кислота, смола на герое (§6.2); значки — в ряду эффектов HUD.
var statuses: Statuses
## Открыто меню паузы (§8.12): мир идёт, как в Dark Souls, но ввод — меню; герой стоит и уязвим.
var in_menu := false
var _swap_buffer := 0.0
## Правый курок геймпада (§8.12): с крестовиной — выбор ячейки, без неё — бросок на отпускании;
## чем дольше держал, тем сильнее заряд.
var _pad_hold := 0.0
var _pad_picked := false
var _preset_charge := 0.0
var _swap_t := 0.0
## Сколько ещё можно ответить контрударом после блока.
var _counter_t := 0.0
var _charge_ready := false
## Лестница, у которой стоит герой (её выставляет сама Ladder).
var ladder: Ladder
## Лежит и спит: вступление в хижине.
var lying := false
## Сколько зон грязи сейчас под героем.
var mud_zones := 0
var _combat_t := 99.0
## Глотки лечебного зелья; пополняются при отдыхе у осколка.
var flasks := 0
var _sipped := false
## Натяжение лука 0…1.
var _draw_t := 0.0
var _draw_sound: AudioStreamPlayer3D
## Верхняя точка текущего полёта — от неё считается высота падения.
var _air_top := 0.0
var _airborne := false
## Где герой последний раз стоял на полу: там остаётся его отзвук, даже если он погиб в яме.
var last_ground := Vector3.ZERO
## Последнее место на земле вне ловушек: здесь остаётся отзвук героя и сюда пишет сохранение.
var safe_ground := Vector3.ZERO
## Кровотечение героя: сколько секунд ещё течёт, сколько в секунду, может ли убить.
var wound_t := 0.0
var _wound_rate := 0.0
var _wound_soft := false
var _wound_drip := 0.0
## С каким оружием погиб — оно угадывается в отзвуке героя.
var death_weapon: StringName = &"sword"
## Чем целится лук: кнопками (прямо / вверх / вниз), мышью — на курсор, правым стиком — куда
## он указывает. Источник меняется сам: двинул мышь, наклонил стик или нажал «вверх»/«вниз».
enum Aim { BUTTONS, MOUSE, STICK }
var aim_source := Aim.BUTTONS
var _aim_point := Vector3.ZERO
var _stick_dir := Vector2.RIGHT
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
	flasks = max_flasks()
	health.heal_full()
	stamina = stats.max_stamina
	health.changed.connect(health_changed.emit)
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	statuses = Statuses.new(health, 1.7)
	add_child(statuses)
	statuses.started.connect(add_effect)
	statuses.ended.connect(remove_effect)
	sword_hitbox.hit_landed.connect(_on_hit_landed)
	plunge_hitbox.hit_landed.connect(_on_hit_landed)
	# Хитбокс меча меняет форму от стадии к стадии — делаем свою копию формы.
	_sword_shape = sword_hitbox_shape.shape.duplicate()
	sword_hitbox_shape.shape = _sword_shape
	arms = PlayerArms.new(visual, sword_pivot)
	body = PlayerBody.new(body_mesh, body_shape.shape as CapsuleShape3D)
	model = HeroModel.new()
	visual.add_child(model)
	arms.attach_hand(model.hand)
	PlayerArms._set_layers(body_mesh, 0)
	attack_step_started.connect(func(step: AttackStep, index: int, _total: int) -> void: model.attack(step, index, not is_on_floor()))
	stats.changed.connect(_on_stats_changed)
	_on_stats_changed()
	# Купленный щит сразу в руке.
	Events.item_found.connect(func(_id: StringName) -> void: _refresh_shield())


func _physics_process(delta: float) -> void:
	if frozen:
		# Стоит у осколка или в переходе: ввода и физики нет, но вид меняется (взросление).
		_update_visual(delta)
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
		State.DRINK: _drink_state(delta)
		State.CHARGE: _charge_state(delta)
		State.LADDER: _ladder_state(delta)
		State.THROW: _throw_state(delta)
	if _head_slide != 0.0:
		velocity.x = _head_slide * HEAD_SLIDE_SPEED
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0
	_limit_blocked_slide()
	_update_rolled_through(delta)
	_after_move()
	_check_enemy_head()
	_foley.update(is_on_floor(), velocity, global_position, delta, state == State.MOVE)
	_track_fall()
	_update_visual(delta)
	_reach.update_prompt(global_position, state != State.DEAD)
	if global_position.y < KILL_Y and state != State.DEAD:
		health.take_damage(INF)


# --- Таймеры и ввод ---------------------------------------------------------

func _tick(delta: float) -> void:
	_tick_wound(delta)
	_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_roll_buffer = maxf(_roll_buffer - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)
	_input_lock = maxf(_input_lock - delta, 0.0)
	_swap_buffer = maxf(_swap_buffer - delta, 0.0)
	_swap_t = maxf(_swap_t - delta, 0.0)
	_parry_t = maxf(_parry_t - delta, 0.0)
	_ledge_cooldown = maxf(_ledge_cooldown - delta, 0.0)
	_shoot_buffer = maxf(_shoot_buffer - delta, 0.0)
	_heal_buffer = maxf(_heal_buffer - delta, 0.0)
	_quick_buffer = maxf(_quick_buffer - delta, 0.0)
	_counter_t = maxf(_counter_t - delta, 0.0)
	_since_slide += delta
	_since_roll += delta
	_combat_t += delta
	hurtbox.invulnerable = _iframes > 0.0 or state == State.DEAD

	if state != State.DEAD and not in_menu:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = stats.jump_buffer
		if Input.is_action_just_pressed("attack"):
			_attack_buffer = stats.attack_buffer
		if Input.is_action_just_pressed("roll"):
			_roll_buffer = stats.input_buffer + _roll_wait()
		if Input.is_action_just_pressed("block") and can_parry():
			_parry_t = stats.parry_window
		if Input.is_action_just_pressed("shoot"):
			_shoot_buffer = stats.input_buffer
		if Input.is_action_just_pressed("heal"):
			_heal_buffer = stats.input_buffer
		# 1–4 только выбирают ячейку; бросок — G (держать — дальше) или тап правого курка.
		for slot in GameState.QUICK_SLOTS:
			if Input.is_action_just_pressed("quick_%d" % (slot + 1)):
				_select_quick(slot)
		if Input.is_action_just_pressed("quick_use"):
			_queue_quick(GameState.active_quick)
		if Input.is_action_pressed("quick_hold"):
			_pad_hold += delta
		elif _pad_hold > 0.0:
			if not _pad_picked:
				_queue_quick(GameState.active_quick)
				_preset_charge = clampf((_pad_hold - PAD_TAP) / THROW_CHARGE_TIME, 0.0, 1.0)
			_pad_hold = 0.0
			_pad_picked = false
		if Input.is_action_just_pressed("interact"):
			_try_interact()
		# Крестовина геймпада — снаряжение, как в Souls; с правым курком она — расходники.
		var quick_held := Input.is_action_pressed("quick_hold")
		if Input.is_action_just_pressed("arrow_swap") and not quick_held and GameState.has_flag(&"has_bow"):
			# Как в Dark Souls: гнёзда стрел I и II переключаются в бою, выбираются у осколка.
			GameState.swap_arrows()
			Sfx.play(&"glass_glint", global_position, -14.0)
		if Input.is_action_just_pressed("weapon_swap") and not quick_held:
			_swap_buffer = stats.input_buffer

	if _stamina_delay > 0.0:
		_stamina_delay -= delta
	elif stamina < stats.max_stamina:
		var regen := stats.mod(&"stamina_regen", stats.stamina_regen) * (stats.block_regen_mult if state == State.BLOCK else 1.0)
		stamina = minf(stamina + regen * delta, stats.max_stamina)
		stamina_changed.emit(stamina, stats.max_stamina)


func _input_x() -> float:
	if _input_lock > 0.0:
		return 0.0
	if Input.is_action_pressed("quick_hold"):
		# Держит кнопку расходников: крестовина выбирает ячейку, идти можно только стиком.
		var stick := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		return stick if absf(stick) > 0.3 else 0.0
	return Input.get_axis("move_left", "move_right")


func _queue_quick(slot: int) -> void:
	_quick_slot = slot
	_quick_buffer = stats.input_buffer
	_preset_charge = 0.0


func _select_quick(slot: int) -> void:
	if slot == GameState.active_quick:
		return
	GameState.select_quick(slot)
	Sfx.play(&"glass_glint", global_position, -18.0)


func _spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_delay = stats.stamina_regen_delay
	stamina_changed.emit(stamina, stats.max_stamina)


func _set_state(new_state: State) -> void:
	if state == State.ATTACK:
		sword_hitbox.active = false
		if new_state != State.ATTACK:
			arms.rest()
	if state in [State.PLUNGE, State.BLOCK, State.GUARD_BROKEN, State.CRITICAL, State.LEDGE_HANG, State.CHARGE]:
		plunge_hitbox.active = false
		arms.rest()
	if state == State.BOW:
		arms.show_bow(false)
		# Выстрел или перекат до полного натяжения — скрип тетивы обрывается. После полного
		# натяжения звук уже кончился, а плеер мог уйти другому событию — его не трогаем.
		if _draw_t < 1.0:
			Sfx.stop(_draw_sound)
		_draw_sound = null
	if state == State.SLIDE:
		_since_slide = 0.0
	if state == State.ROLL:
		_since_roll = 0.0
	if state == State.THROW and is_instance_valid(_throw_hand):
		_throw_hand.queue_free()
		_throw_hand = null
	state = new_state
	_state_time = 0.0
	if state == State.BLOCK:
		arms.guard()
	elif state == State.GUARD_BROKEN:
		arms.guard_broken()
	elif state == State.LEDGE_HANG:
		# Руки заняты краем — меч прижат клинком вниз.
		arms.point_down()
	_refresh_shield()


func _apply_gravity(delta: float) -> void:
	var g := stats.gravity
	if velocity.y < 0.0:
		g *= stats.fall_multiplier
	elif not Input.is_action_pressed("jump"):
		g *= stats.jump_cut_multiplier
	velocity.y = maxf(velocity.y - g * delta, -stats.max_fall_speed)


# --- Состояния --------------------------------------------------------------

func _move_state(delta: float) -> void:
	if in_menu:
		_menu_state(delta)
		return
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = stats.coyote_time
	var x := _input_x()
	if x != 0.0:
		facing = signf(x)

	var target := x * stats.move_speed * _slow(MUD_SPEED, TAR_SPEED)
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
	elif _roll_buffer > 0.0 and not roll_cooling() and (on_floor or _coyote > 0.0):
		_start_roll()
	elif _attack_buffer > 0.0 and _swap_t <= 0.0:
		if not on_floor and weapon and Input.is_action_pressed("move_down"):
			_start_plunge()
		else:
			_start_attack()
	elif _quick_buffer > 0.0:
		_start_throw()
	elif _shoot_buffer > 0.0:
		_start_draw()
	elif _heal_buffer > 0.0 and on_floor:
		_start_drink()
	elif _swap_buffer > 0.0:
		swap_sets()
	elif on_floor and weapon and Input.is_action_pressed("block"):
		_set_state(State.BLOCK)
	elif ladder and (Input.is_action_pressed("move_up") or (not on_floor and Input.is_action_pressed("move_down"))):
		_set_state(State.LADDER)
	elif _wants_climb(x, on_floor):
		_set_state(State.CLIMB)
	elif not on_floor and x != 0.0:
		_try_grab_ledge(signf(x))


func _jump() -> void:
	velocity.y = stats.jump_velocity * _slow(MUD_JUMP, TAR_JUMP)
	Sfx.play(&"player_jump", global_position)
	if jump_is_effort():
		Sfx.play(&"player_jump_voice", global_position)
	_jump_buffer = 0.0
	_coyote = 0.0


## Прыжок с усилием: с разгона (скольжение, подкат), сразу после кувырка или когда герой выдохся.
func jump_is_effort() -> bool:
	return absf(velocity.x) > stats.move_speed * EFFORT_SPEED \
		or _since_roll < stats.roll_attack_window \
		or stamina < stats.max_stamina * EFFORT_STAMINA


## Уровень или перераспределение: запас здоровья и выносливости растёт, вид догоняет возраст.
func _on_stats_changed() -> void:
	var gained := stats.max_health - health.max_health
	health.max_health = stats.max_health
	if gained != 0.0:
		health.current = clampf(health.current + maxf(gained, 0.0), 0.0, health.max_health)
		health.changed.emit(health.current, health.max_health)
	stamina = minf(stamina, stats.max_stamina)
	stamina_changed.emit(stamina, stats.max_stamina)
	body.set_hair_color(AgeLook.hair_color(stats.current_age))


func _start_roll() -> void:
	# Пауза после прошлого кувырка: нажатие ждёт в буфере, пока она не кончится.
	if roll_cooling():
		return
	# Вне боя кувырок бесплатный; в бою — по цене, и без выносливости его нет.
	var cost := roll_cost_now()
	if cost > 0.0 and stamina < cost:
		_roll_buffer = 0.0
		stamina_short.emit()
		return
	_roll_buffer = 0.0
	if cost > 0.0:
		_spend_stamina(cost)
	var x := _input_x()
	_roll_dir = signf(x) if x != 0.0 else facing
	facing = _roll_dir
	# Подкат сохраняет скорость, если она больше обычной скорости переката.
	var carried := absf(velocity.x) if signf(velocity.x) == _roll_dir else 0.0
	_roll_speed = maxf(stats.roll_speed, carried) * _slow(MUD_ROLL_SPEED, TAR_ROLL_SPEED)
	_iframes = maxf(_iframes, stats.roll_iframes)
	_roll_attack_queued = false
	_pass_through_bosses()
	_set_state(State.ROLL)
	Sfx.play(&"player_roll", global_position)


func _roll_state(delta: float) -> void:
	var t := minf(_state_time / stats.roll_duration, 1.0)
	velocity.x = _roll_dir * _roll_speed * (1.0 - 0.4 * t)
	_apply_gravity(delta)
	# Удар, нажатый в кувырке, выходит сразу после него — «по инерции».
	if _attack_buffer > 0.0:
		_attack_buffer = 0.0
		_roll_attack_queued = true
	if _state_time >= stats.roll_duration:
		# Внутри врага перекат не заканчивается; упёрлись в стену — выходим обратно.
		if _boss_around():
			_iframes = maxf(_iframes, delta * 2.0)
			if is_on_wall() and get_wall_normal().x * _roll_dir < 0.0:
				_roll_dir = -_roll_dir
				facing = _roll_dir
			return
		var queued := _roll_attack_queued
		_set_state(State.MOVE)
		if queued:
			_start_attack()


## Кувырок ещё нельзя: не прошла пауза после прошлого.
func roll_cooling() -> bool:
	return state != State.ROLL and _since_roll < stats.roll_cooldown


## Сколько ещё ждать кувырка: остаток этого кувырка (если нажали под его конец) и пауза.
func _roll_wait() -> float:
	if state == State.ROLL:
		var left := stats.roll_duration - _state_time
		return left + stats.roll_cooldown if left < stats.input_buffer else 0.0
	return maxf(stats.roll_cooldown - _since_roll, 0.0)


func _pass_through_bosses() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Dummy
		if enemy and enemy.roll_through and enemy not in _rolled_through:
			add_collision_exception_with(enemy)
			enemy.add_collision_exception_with(self)
			_rolled_through.append(enemy)


## Враг, внутри которого стоит герой, или null.
func _boss_around() -> Dummy:
	var radius := (body_shape.shape as CapsuleShape3D).radius
	for enemy in _rolled_through:
		if is_instance_valid(enemy) and enemy.is_inside_tree() \
				and absf(global_position.x - enemy.global_position.x) < enemy.body_half_width() + radius:
			return enemy
	return null


## После переката враг снова твёрдый. Если перекат сорвали внутри него — выдавливает наружу.
func _update_rolled_through(delta: float) -> void:
	if state == State.ROLL or _rolled_through.is_empty():
		return
	var inside := _boss_around()
	if inside:
		var side := signf(global_position.x - inside.global_position.x)
		move_and_collide(Vector3((side if side != 0.0 else facing) * THROUGH_PUSH * delta, 0.0, 0.0))
		return
	for enemy in _rolled_through:
		if is_instance_valid(enemy):
			remove_collision_exception_with(enemy)
			enemy.remove_collision_exception_with(self)
	_rolled_through.clear()


## Идёт ли бой: враг рядом бьётся с героем, или удары были только что.
func in_combat() -> bool:
	if _combat_t < COMBAT_LINGER:
		return true
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Dummy
		if enemy and enemy.state in COMBAT_STATES \
				and absf(enemy.global_position.x - global_position.x) < COMBAT_RANGE \
				and absf(enemy.global_position.y - global_position.y) < 6.0:
			return true
	return false


func in_mud() -> bool:
	return mud_zones > 0


func in_tar() -> bool:
	return statuses.has(Statuses.TAR)


## Вязкость под ногами: грязь и смола, берётся сильнейшая.
func _slow(mud: float, tar: float) -> float:
	return minf(mud if in_mud() else 1.0, tar if in_tar() else 1.0)


func roll_cost_now() -> float:
	if not in_combat():
		return 0.0
	return stats.roll_cost * maxf(MUD_ROLL_COST if in_mud() else 1.0, TAR_ROLL_COST if in_tar() else 1.0)


## Глотков зелья: стартовые и найденные сосуды.
func max_flasks() -> int:
	return stats.flask_charges + GameState.item_count(&"flask_vessel")


## Выбор удара: добивание или удар в спину → продолжение комбо → удар из скольжения
## → удар после кувырка → первая стадия комбо.
func _start_attack() -> void:
	if stamina <= 0.0 or weapon == null or weapon.combo.is_empty():
		return
	var series := _series()
	var x := _input_x()
	if x != 0.0 and state != State.SLIDE:
		facing = signf(x)
	if _try_critical():
		return
	if _counter_t > 0.0 and weapon.counter:
		_counter_t = 0.0
		_begin_attack(weapon.counter, 0)
	elif state == State.ATTACK:
		var chaining := _combo > 0 and _combo < series.size()
		var index := _combo + 1 if chaining else 1
		_begin_attack(series[index - 1], index)
	elif weapon.slide_attack and (state == State.SLIDE or _since_slide < stats.slide_attack_window):
		_begin_attack(weapon.slide_attack, 0)
	elif weapon.roll_attack and _since_roll < stats.roll_attack_window:
		_begin_attack(weapon.roll_attack, 0)
	elif weapon.air_attack and not is_on_floor() and _mastery_step() >= WeaponData.STEP_AIR:
		_begin_attack(weapon.air_attack, 0)
	else:
		_begin_attack(series[0], 1)


## index — номер стадии комбо; 0 — особый удар, после него комбо начинается заново.
func _begin_attack(step: AttackStep, index: int) -> void:
	_attack_buffer = 0.0
	_spend_stamina(stats.attack_cost * step.stamina_mult)
	_combo = index
	_step = step
	_impact_done = false
	# Импульс переходит в удар: первый удар на высокой скорости тяжелее.
	_fast_attack = index <= 1 and absf(velocity.x) > stats.move_speed * 1.2
	var bonus := 1.3 if _fast_attack else 1.0
	sword_hitbox.damage = _blade_damage() * step.damage_multiplier * bonus
	sword_hitbox.weapon_type = weapon.type
	sword_hitbox.bleed = _bleed_of(step.damage_multiplier)
	sword_hitbox.poise_damage = step.poise_damage * bonus
	sword_hitbox.heavy = step.heavy or _fast_attack
	sword_hitbox.knockback = maxf(step.knockback, 8.0 if _fast_attack else 0.0)
	_sword_shape.size = Vector3(step.hitbox_size.x, step.hitbox_size.y, 1.8)
	sword_hitbox_shape.position = Vector3(step.hitbox_offset.x, step.hitbox_offset.y, 0.0)
	_set_state(State.ATTACK)
	arms.swing(step)
	Sfx.play(step.swing_sound, global_position)
	attack_step_started.emit(step, index, _series().size())


func _attack_state(delta: float) -> void:
	var t := _state_time
	sword_hitbox.active = t >= _step.active_from and t <= _step.active_to
	var on_floor := is_on_floor()
	if _floor_glass_normal != Vector3.ZERO:
		# Удар в скольжении: скат продолжает нести героя.
		_slide_physics(delta)
	else:
		# Шаг в удар — со второй половины замаха, а не с первого кадра (§6.1).
		var lunge := facing * _step.lunge_speed if t >= _step.active_from * 0.5 and t < _step.active_to else 0.0
		var decel := stats.momentum_decay * 2.0 if on_floor else stats.air_acceleration * 0.5
		velocity.x = move_toward(velocity.x, lunge, decel * delta)
		_apply_gravity(delta)
		if t < _step.air_hover and velocity.y < 0.0:
			velocity.y = 0.0
	if _step.ground_impact and not _impact_done and t >= _step.active_to and on_floor:
		_impact_done = true
		_ground_impact()
	if t >= _step.chain_from:
		if _roll_buffer > 0.0 and on_floor:
			_start_roll()
			return
		if _attack_buffer > 0.0 and _combo < _series().size():
			_start_attack()
			return
	if t >= _step.duration:
		if _step.follow_up:
			_begin_attack(_step.follow_up, 0)
			return
		# Удар всё ещё держат — заряд. Лёгкий удар не ждёт: сначала взмах, заряд после него.
		if on_floor and weapon.charged and _step != weapon.charged and Input.is_action_pressed("attack"):
			_start_charge()
			return
		_set_state(State.SLIDE if _floor_glass_normal != Vector3.ZERO else State.MOVE)


func _start_plunge() -> void:
	if stamina <= 0.0:
		return
	_attack_buffer = 0.0
	_spend_stamina(stats.attack_cost)
	plunge_hitbox.damage = _blade_damage() * 1.5
	plunge_hitbox.weapon_type = weapon.type if weapon else &""
	plunge_hitbox.bleed = _bleed_of(1.5)
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
	_slide_speed = clampf(_slide_speed, -stats.move_speed, stats.mod(&"max_slide_speed", stats.max_slide_speed))
	velocity = down * _slide_speed
	return down


func _climb_state(_delta: float) -> void:
	if in_menu:
		_menu_state(_delta)
		return
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
	velocity.y = v * stats.mod(&"climb_speed", stats.climb_speed) if v != 0.0 else -stats.climb_slip
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
	if weapon and arms.dropped_weapon() == null and _state_time >= PlayerBody.SLUMP_TIME:
		arms.drop_weapon(get_parent(), facing)
	if not _death_landed and body.landed(_state_time):
		_death_landed = true
		Sfx.play(&"player_body_fall", global_position)


func _block_state(delta: float) -> void:
	if in_menu:
		_menu_state(delta)
		return
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
			_critical_target.last_weapon = weapon.type
			_critical_target.apply_critical(_blade_damage() * _step.damage_multiplier * stats.critical_mult,
				_step.victim_throw, global_position.x)
	if _state_time >= _step.duration:
		_set_state(State.MOVE)


func _critical_spark(strength: float) -> void:
	HitStop.stop(_step.hitstop * strength)
	Events.camera_shake_requested.emit(0.45 * strength, 0.3)
	if is_instance_valid(_critical_target):
		var at := _critical_target.global_position + Vector3(0.0, 1.1 + _step.victim_lift, 0.3)
		HitSpark.spawn(get_parent(), at, Color(1.0, 0.45, 0.3), int(32 * strength))


# --- Оружие: мастерство и заряд ---------------------------------------------

## Взять оружие по id; пусто — руки пусты.
func equip(id: StringName) -> void:
	weapon = WeaponData.by_id(id) if id != &"" else null
	GameState.weapon_id = id
	GameState.own_weapon(id)
	arms.set_weapon(weapon)
	_refresh_shield()


## Сменить набор оружия: II в руку, I — в запас (§8.12). Набора II нет — ничего.
## Пока оружие в пути (SWAP_TIME), удара нет; ходить и прыгать можно.
func swap_sets() -> void:
	_swap_buffer = 0.0
	var other := GameState.second_weapon_id
	if other == &"" or other == GameState.weapon_id:
		return
	GameState.second_weapon_id = GameState.weapon_id
	equip(other)
	_swap_t = SWAP_TIME
	_attack_buffer = 0.0
	Sfx.play(&"weapon_drop", global_position, -10.0)


## Меню паузы: герой стоит, но живёт — падает, его бьют; на лестнице и стене держится.
func _menu_state(delta: float) -> void:
	if state in [State.LADDER, State.CLIMB]:
		velocity = Vector3.ZERO
		return
	if state == State.BLOCK:
		_set_state(State.MOVE)
	var accel := stats.friction if is_on_floor() else stats.air_drag
	velocity.x = move_toward(velocity.x, 0.0, accel * delta)
	_apply_gravity(delta)


func has_shield() -> bool:
	return GameState.item_count(GameState.SHIELD_ITEM) > 0 and GameState.shield_worn


## Щит надели или сняли в «Снаряжении».
func refresh_shield() -> void:
	_refresh_shield()


## Щит в руке: есть, оружие не двуручное и лук не натянут.
func shield_in_hand() -> bool:
	return has_shield() and not (weapon and weapon.two_handed) and state != State.BOW


## Щит в руке, выставлен в блоке или висит за спиной.
func _refresh_shield() -> void:
	if arms == null:
		return
	if not has_shield():
		arms.place_shield(PlayerArms.ShieldAt.NONE)
	elif not shield_in_hand():
		arms.place_shield(PlayerArms.ShieldAt.BACK)
	elif state == State.BLOCK:
		arms.place_shield(PlayerArms.ShieldAt.GUARD)
	else:
		arms.place_shield(PlayerArms.ShieldAt.HAND)


## Молот ударил в пол: тряска, крошка и звук камня — и без попадания по врагу.
func _ground_impact() -> void:
	var at := global_position + Vector3(facing * (_step.hitbox_offset.x + 0.3), 0.1, 0.3)
	Events.camera_shake_requested.emit(0.4 if _step.heavy else 0.25, 0.25)
	Sfx.play(&"sword_block", at, 2.0 if _step.heavy else -2.0)
	HitSpark.spawn(get_parent(), at, Color(0.5, 0.48, 0.45), 24 if _step.heavy else 12)


## Лестница: вверх-вниз без гравитации. Наверху — подтягивается на этаж; прыжок — соскочил.
func _ladder_state(_delta: float) -> void:
	if in_menu:
		_menu_state(_delta)
		return
	if ladder == null:
		_set_state(State.MOVE)
		return
	var v := Input.get_axis("move_down", "move_up")
	velocity = Vector3(0.0, v * stats.mod(&"climb_speed", stats.climb_speed), 0.0)
	global_position.x = move_toward(global_position.x, ladder.global_position.x, 6.0 * _delta)
	if global_position.y >= ladder.top_y():
		velocity = Vector3(ladder.exit_dir * 4.5, 5.0, 0.0)
		facing = ladder.exit_dir
		_set_state(State.MOVE)
	elif _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = Vector3(_input_x() * stats.move_speed, stats.jump_velocity * 0.7, 0.0)
		_set_state(State.MOVE)
	elif v < 0.0 and is_on_floor():
		_set_state(State.MOVE)


func _mastery_step() -> int:
	return GameState.mastery_step(weapon.type) if weapon else 0


## Щит парирует сразу (§6.2). Без него — только оружие, которым герой овладел до первой
## ступени; до этого — блок.
func can_parry() -> bool:
	return shield_in_hand() or _mastery_step() >= WeaponData.STEP_PARRY


func _series() -> Array[AttackStep]:
	return weapon.combo_at(_mastery_step())


## Урон клинка: возраст и грани (PlayerStats), характеристики по скалированию оружия
## и закалённое стекло в нём.
func _blade_damage() -> float:
	if weapon == null:
		return stats.sword_damage
	return weapon_damage(weapon, GameState.glass_level(weapon.id))


## Урон оружия с таким шагом закалки и набранными очками (extra): для меню «было → станет».
func weapon_damage(of: WeaponData, glass_level: int, extra := {}) -> float:
	var glass := 1.0 + glass_level * GameState.GLASS_DAMAGE_STEP
	return stats.sword_damage * (1.0 + stats.attribute_bonus(of.scaling, extra)) * of.damage_mult * glass


## Эффекты на герое: id → сколько источников держат его (две лужи грязи — один эффект).
var effects := {}


func add_effect(id: StringName) -> void:
	effects[id] = effects.get(id, 0) + 1
	if effects[id] == 1:
		effects_changed.emit()


func remove_effect(id: StringName) -> void:
	if not effects.has(id):
		return
	effects[id] -= 1
	if effects[id] <= 0:
		effects.erase(id)
		effects_changed.emit()


func has_effect(id: StringName) -> bool:
	return effects.has(id)


## Вес снаряжения: оружие обоих наборов, щит и лук (§8.6).
func equip_weight() -> float:
	var total := 0.0
	for id: StringName in [GameState.weapon_id, GameState.second_weapon_id]:
		if id != &"":
			total += WeaponData.by_id(id).weight
	if has_shield():
		total += SHIELD_WEIGHT
	if GameState.has_flag(&"has_bow"):
		total += BOW_WEIGHT
	return total


## Кровотечение удара: только у мастера, сильнее удар — больше.
func _bleed_of(power: float) -> float:
	if weapon == null or _mastery_step() < WeaponData.STEP_SPECIAL:
		return 0.0
	return weapon.bleed_buildup * power * stats.bleed_mult


func _start_charge() -> void:
	_charge_ready = false
	_set_state(State.CHARGE)
	arms.charge_pose()


## Заряд: герой идёт шагом, клинок отведён. Полный — вспышка; отпустил полный — заряженный удар,
## раньше — просто опустил клинок.
func _charge_state(delta: float) -> void:
	var x := _input_x()
	if x != 0.0:
		facing = signf(x)
	var accel := stats.acceleration if is_on_floor() else stats.air_acceleration
	velocity.x = move_toward(velocity.x, x * stats.move_speed * stats.charge_move_mult, accel * delta)
	_apply_gravity(delta)
	if not _charge_ready and _state_time >= stats.charge_time:
		_charge_ready = true
		body.flash(Color(1.0, 0.85, 0.5))
		Sfx.play(&"glass_glint", global_position, -8.0)
	if _roll_buffer > 0.0 and is_on_floor():
		_start_roll()
	elif not Input.is_action_pressed("attack"):
		if _charge_ready and stamina > 0.0:
			_begin_attack(weapon.charged, 0)
		else:
			_set_state(State.MOVE)


# --- Зелье ------------------------------------------------------------------

## Глоток зелья: глоток тратится сразу, лечит в момент глотка (flask_sip_at). Ударили раньше —
## зелье пролито, как в Souls. Пока пьёт — идёт шагом, оружие опущено.
func _start_drink() -> void:
	_heal_buffer = 0.0
	if flasks <= 0:
		return
	flasks -= 1
	flasks_changed.emit(flasks, max_flasks())
	_sipped = false
	_set_state(State.DRINK)


func _drink_state(delta: float) -> void:
	var x := _input_x()
	if x != 0.0:
		facing = signf(x)
	var accel := stats.acceleration if is_on_floor() else stats.air_acceleration
	velocity.x = move_toward(velocity.x, x * stats.move_speed * stats.flask_move_mult, accel * delta)
	_apply_gravity(delta)
	if not _sipped and _state_time >= stats.flask_drink_time * stats.flask_sip_at:
		_sipped = true
		var potency := stats.flask_heal + FLASK_POTENCY_STEP * GameState.item_count(&"flask_potency")
		health.heal(stats.max_health * stats.mod(&"flask_heal", potency))
		body.flash(Color(0.45, 1.0, 0.6))
		HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 1.2, 0.3), Color(0.5, 1.0, 0.65), 14)
	if _state_time >= stats.flask_drink_time:
		_set_state(State.MOVE)


# --- Броски расходников ----------------------------------------------------

## Ячейка крестовины нажата: в ней расходник и он ещё есть — бросок. Пустая или кончилась — ничего.
func _start_throw() -> void:
	_quick_buffer = 0.0
	var id := GameState.quick_item(_quick_slot)
	var item := ConsumableData.by_id(id)
	if item == null or GameState.item_count(id) <= 0:
		return
	if stamina <= 0.0:
		stamina_short.emit()
		return
	_throw_item = item
	_thrown = false
	throw_charge = 0.0
	_charge_done = item.charge_speed_mult <= 1.0
	# Геймпад: заряд набран, пока держали курок, — бросок сразу с ним.
	if _preset_charge > 0.0 and not _charge_done:
		throw_charge = _preset_charge
		_charge_done = true
	_preset_charge = 0.0
	_set_state(State.THROW)
	# Заглушка в руке: отведена за плечо и идёт вперёд до выпуска.
	_throw_hand = Thrown.make_look(item)
	visual.add_child(_throw_hand)
	_throw_hand.position = Vector3(-0.25, 1.6, 0.25)


## Держит ли герой кнопку броска (G). С геймпада заряд приходит готовым — _preset_charge.
func _quick_held(_slot: int) -> bool:
	return Input.is_action_pressed("quick_use")


## Замах и выпуск: на ходу медленнее, в воздухе — по инерции. После выпуска кувырок отменяет бросок.
func _throw_state(delta: float) -> void:
	var x := _input_x()
	var accel := stats.acceleration if is_on_floor() else stats.air_acceleration
	velocity.x = move_toward(velocity.x, x * stats.move_speed * THROW_MOVE_MULT, accel * delta)
	_apply_gravity(delta)
	var item := _throw_item
	if not _thrown:
		# Рука сначала почти стоит за плечом, потом резко идёт вперёд. Держит ячейку в момент
		# «взвода» — замирает и отводится дальше, пока не отпустит или заряд не станет полным.
		var cock := item.release_at * 0.55
		if not _charge_done and _state_time >= cock:
			if _quick_held(_quick_slot) and throw_charge < 1.0:
				throw_charge = minf(throw_charge + delta / THROW_CHARGE_TIME, 1.0)
				_state_time = cock
			else:
				_charge_done = true
		var k := pow(clampf(_state_time / item.release_at, 0.0, 1.0), 2.5)
		if is_instance_valid(_throw_hand):
			var back := Vector3(-0.3, 0.12, 0.0) * throw_charge * (1.0 if not _charge_done else 1.0 - k)
			_throw_hand.position = Vector3(-0.25, 1.6, 0.25).lerp(Vector3(0.5, 1.4, 0.25), k) + back
			_throw_hand.rotation.z = lerpf(1.2 + 0.5 * throw_charge, -0.3, k)
		if _state_time >= item.release_at:
			_release_throw(item)
	elif _roll_buffer > 0.0 and is_on_floor() and not roll_cooling():
		_start_roll()
		return
	if _state_time >= item.duration:
		_set_state(State.MOVE)


func _release_throw(item: ConsumableData) -> void:
	_thrown = true
	if is_instance_valid(_throw_hand):
		_throw_hand.queue_free()
		_throw_hand = null
	# Предмет тратится на выпуске: сбили на замахе — нож остался.
	if not GameState.take_item(item.id):
		return
	# «Вверх» — круче; на геймпаде верх крестовины выбирает ячейку, а не угол.
	var up := Input.is_action_pressed("move_up") and not Input.is_action_pressed("quick_hold")
	var angle := deg_to_rad(item.angle + (THROW_UP_ANGLE if up else 0.0))
	var dir := Vector3(cos(angle) * facing, sin(angle), 0.0)
	var at := global_position + Vector3(0.0, THROW_HEIGHT, 0.0) + Vector3(facing * THROW_REACH, 0.0, 0.0)
	var speed := item.speed * lerpf(1.0, item.charge_speed_mult, throw_charge)
	var thrown := Thrown.spawn(get_parent(), at, dir * speed, item, stats.throw_damage_mult)
	_spend_stamina(item.stamina_cost)
	Sfx.play(&"sword_swing", at, -6.0)
	item_thrown.emit(thrown)


# --- Лук --------------------------------------------------------------------

func _start_draw() -> void:
	_shoot_buffer = 0.0
	if stamina <= 0.0 or not GameState.has_flag(&"has_bow"):
		return
	_draw_t = 0.0
	_set_state(State.BOW)
	arms.show_bow(true)
	_draw_sound = Sfx.play(&"bow_draw", global_position)
	if _draw_sound:
		_draw_sound.pitch_scale *= clampf(BOW_DRAW_SOUND_TIME / _bow_draw_time(), 0.8, 1.25)


## Натяжение: держим кнопку — лук натягивается, герой идёт медленно. Отпустили — выстрел.
## Мышью лук смотрит на курсор, правым стиком — куда наклонён стик (отпустил — направление
## остаётся); герой разворачивается к цели и может пятиться. Кнопками — прямо, вверх или вниз.
func _bow_state(delta: float) -> void:
	_draw_t = minf(_draw_t + delta / _bow_draw_time(), 1.0)
	var x := _input_x()
	var stick := Input.get_vector("aim_left", "aim_right", "aim_down", "aim_up")
	if stick != Vector2.ZERO:
		aim_source = Aim.STICK
		_stick_dir = stick.normalized()
	if aim_source == Aim.MOUSE:
		_mouse_aim_point()
	elif aim_source == Aim.BUTTONS and x != 0.0:
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
	var damage := lerpf(stats.bow_damage_min, stats.bow_damage_max, _draw_t) * stats.bow_damage_mult * GameState.bow_damage_mult()
	var poise_dmg := lerpf(stats.bow_poise_min, stats.bow_poise_max, _draw_t)
	# Особые стрелы активного гнезда тратятся на выпуске; кончились — летит обычная.
	var kind := ArrowData.by_id(GameState.current_arrow())
	if kind and GameState.take_item(kind.id):
		damage *= kind.damage_mult
	else:
		kind = null
	# Стрела вылетает из лука — по линии прицела от плеча.
	var at := global_position + Vector3(0.0, BOW_HEIGHT, 0.0) + dir * BOW_REACH
	var arrow := Arrow.spawn(get_parent(), at, dir * speed, damage, poise_dmg, kind)
	Sfx.play(&"bow_release", at)
	_spend_stamina(stats.bow_cost)
	_set_state(State.MOVE)
	arrow_fired.emit(arrow)


## Прицел — угол от горизонтали вперёд по взгляду: −90° — вниз, +90° — вверх.
## Мышью — на курсор, стиком — по стику; кнопками — прямо, с «вверх» круто вверх,
## с «вниз» в воздухе вниз.
func _aim_angle() -> float:
	if aim_source == Aim.MOUSE:
		return aim_toward(_aim_point)
	if aim_source == Aim.STICK:
		var origin := global_position + Vector3(0.0, BOW_HEIGHT, 0.0)
		return aim_toward(origin + Vector3(_stick_dir.x, _stick_dir.y, 0.0))
	if Input.is_action_pressed("move_up"):
		return deg_to_rad(stats.aim_up_angle)
	if Input.is_action_pressed("move_down") and not is_on_floor():
		return -deg_to_rad(stats.aim_down_angle)
	return 0.0


## Повернуться к точке мира и вернуть угол прицела на неё (от лука на высоте плеча).
## Курсор почти над головой или под ногами — взгляд не дёргается туда-сюда.
func aim_toward(point: Vector3) -> float:
	var d := point - (global_position + Vector3(0.0, BOW_HEIGHT, 0.0))
	if absf(d.x) > 0.15:
		facing = signf(d.x)
	return atan2(d.y, maxf(absf(d.x), 0.001))


## Куда смотрит курсор в плоскости боя (z = 0): луч камеры через указатель.
func _mouse_aim_point() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	if absf(normal.z) < 0.001:
		return
	_aim_point = from + normal * (-from.z / normal.z)


## Мышь двинулась — целимся ею; нажали «вверх»/«вниз» с клавиатуры или крестовины — по-старому.
## Стик включается сам в _bow_state, когда его наклоняют.
func _unhandled_input(event: InputEvent) -> void:
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed and QUICK_PAD.has(pad.button_index) and Input.is_action_pressed("quick_hold") \
			and state != State.DEAD and not frozen:
		_select_quick(QUICK_PAD[pad.button_index])
		_pad_picked = true
		return
	if event is InputEventMouseMotion:
		aim_source = Aim.MOUSE
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		aim_source = Aim.BUTTONS


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
	Sfx.play(&"player_jump_voice", global_position)
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
	_combat_t = 0.0
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
	_combat_t = 0.0
	if hitbox.wound_chance > 0.0 and randf() < hitbox.wound_chance:
		start_wound(hitbox.wound_total, hitbox.wound_time, hitbox.non_lethal)
	body.flash(Color(1.0, 0.25, 0.2))
	Sfx.play(&"player_hurt", global_position)
	Events.camera_shake_requested.emit(0.3, 0.2)
	if health.is_dead():
		return
	# Стойкость (§8.6): удар слабее порога ранит, но не сбивает; тяжёлый сбивает всегда.
	if not hitbox.heavy and hitbox.poise_damage < stats.poise:
		_iframes = POISE_IFRAMES
		return
	HitStop.stop(0.07)
	var dir := hitbox.knockback_direction(self)
	velocity = Vector3(dir.x * hitbox.knockback, 5.0, 0.0)
	_iframes = stats.hurt_iframes
	_set_state(State.HURT)


func _bow_draw_time() -> float:
	return stats.mod(&"bow_draw_time", stats.bow_draw_time) * GameState.bow_draw_mult()


## Стоит ли герой на ловушке (шипы и т. п. в группе "hazard").
func _on_hazard() -> bool:
	for node in get_tree().get_nodes_in_group("hazard"):
		if node.has_method("covers") and node.covers(global_position):
			return true
	return false


## Рана кровоточит: здоровье капает wound_time секунд. Новая рана не складывается, а продлевает.
func start_wound(total: float, time: float, soft := false) -> void:
	if time <= 0.0 or is_dead():
		return
	_wound_rate = maxf(_wound_rate if wound_t > 0.0 else 0.0, total / time)
	wound_t = maxf(wound_t, time)
	_wound_soft = soft
	body.flash(Color(0.75, 0.05, 0.05))
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 1.1, 0.3), Color(0.6, 0.02, 0.02), 14)


func _tick_wound(delta: float) -> void:
	if wound_t <= 0.0:
		return
	if is_dead():
		wound_t = 0.0
		return
	wound_t -= delta
	health.take_damage(_wound_rate * delta, _wound_soft)
	_wound_drip -= delta
	if _wound_drip <= 0.0:
		_wound_drip = 0.3
		HitSpark.spawn(get_parent(), global_position + Vector3(randf_range(-0.2, 0.2), 0.9, 0.3), Color(0.55, 0.02, 0.02), 4)


func _on_parry(attacker: Dummy) -> void:
	_parry_t = 0.0
	Sfx.play(&"sword_parry", global_position + Vector3(facing * 0.6, 1.2, 0.0))
	HitStop.stop(0.12)
	Events.camera_shake_requested.emit(0.3, 0.2)
	var at := (global_position + attacker.global_position) * 0.5 + Vector3(0.0, 1.2, 0.3)
	HitSpark.spawn(get_parent(), at, Color(1.0, 0.95, 0.6), 26)


## Удар принят на блок: урона нет, но он стоит выносливости. Не хватило — блок пробит.
func _on_block(hitbox: Hitbox) -> void:
	var cost := hitbox.damage * stats.block_stamina_mult * (SHIELD_BLOCK_MULT if shield_in_hand() else 1.0)
	var at := global_position + Vector3(facing * 0.6, 1.2, 0.3)
	# Пробитый блок звенит громче: клинок отбит.
	Sfx.play(&"sword_block", at, 0.0 if stamina >= cost else 4.0)
	if stamina >= cost:
		_spend_stamina(cost)
		if _mastery_step() >= WeaponData.STEP_COUNTER:
			_counter_t = stats.counter_window
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
	death_weapon = held_weapon()
	_set_state(State.DEAD)
	_death_landed = false
	_death_dir = body.fall_direction(self, facing)
	Sfx.play(&"player_knee", global_position)
	died.emit()
	Events.player_died.emit()


## Возрождение у осколка: полное здоровье и выносливость, короткая неуязвимость.
## Сбит с ног и лежит: сцена ведёт героя сама, ввода нет.
## Сцена берёт героя: замер на земле; lie — ещё и лежит.
func knock_down(lie := true) -> void:
	_set_state(State.MOVE)
	velocity = Vector3.ZERO
	global_position.y = last_ground.y if not is_on_floor() else global_position.y
	frozen = true
	lying = lie


func stand_up() -> void:
	lying = false
	frozen = false


func respawn(at: Vector3) -> void:
	wound_t = 0.0
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
	_airborne = false
	_air_top = global_position.y
	last_ground = global_position
	safe_ground = global_position


## Высота падения: от верхней точки полёта до пола. Лазание, скольжение по скату и вис
## на краю полёт прерывают — с них высота считается заново.
func _track_fall() -> void:
	if state == State.DEAD:
		_airborne = false
		return
	var y := global_position.y
	var grounded := is_on_floor()
	if grounded or state in [State.CLIMB, State.SLIDE, State.LEDGE_HANG, State.LEDGE_CLIMB, State.LADDER]:
		if _airborne and grounded:
			_land_from(_air_top - y)
		if grounded:
			last_ground = global_position
			if not _on_hazard():
				safe_ground = global_position
		_airborne = false
		_air_top = y
	else:
		_airborne = true
		_air_top = maxf(_air_top, y)


## Урон от падения с высоты drop (м): кувырок и неуязвимость не спасают.
func _land_from(drop: float) -> void:
	if drop <= stats.fall_safe_height:
		return
	var t := (drop - stats.fall_safe_height) / maxf(stats.fall_lethal_height - stats.fall_safe_height, 0.01)
	Sfx.play(&"player_fall_hurt", global_position)
	body.flash(Color(1.0, 0.25, 0.2))
	Events.camera_shake_requested.emit(lerpf(0.2, 0.7, minf(t, 1.0)), 0.25)
	health.take_damage(stats.max_health * pow(t, stats.fall_damage_power) if t < 1.0 else INF)


func restore() -> void:
	statuses.clear()
	wound_t = 0.0
	health.heal_full()
	stamina = stats.max_stamina
	stamina_changed.emit(stamina, stats.max_stamina)
	flasks = max_flasks()
	flasks_changed.emit(flasks, max_flasks())


func is_dead() -> bool:
	return state == State.DEAD


## Копия облика для отзвука героя и отражения: фигура и оружие (лук — в руке, меч — в покое),
## без хитбоксов; лицо — только у отражения. Материал задаёт тот, кто просит копию.
func make_silhouette(weapon: StringName, keep_face := false) -> Node3D:
	var copy := ($Visual as Node3D).duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	for node in copy.find_children("*", "Area3D", true, false):
		node.free()
	var face := copy.find_child("Face", true, false)
	if face and not keep_face:
		face.free()
	var bow := copy.find_child("Bow", true, false) as Node3D
	var sword := copy.find_child(arms.sword_pivot.name, true, false) as Node3D
	if bow:
		bow.visible = weapon == &"bow"
	if sword:
		sword.visible = weapon == &"sword"
	var grip := copy.find_child("Grip", true, false) as Node3D
	if grip:
		grip.visible = weapon == &"sword"
	return copy


## С каким оружием в руках герой сейчас: для отзвука героя и отражения.
func held_weapon() -> StringName:
	if state == State.BOW:
		return &"bow"
	return &"sword" if weapon else &""


# --- Взаимодействие ---------------------------------------------------------

func add_interactable(target: Interactable) -> void:
	_reach.add(target)


func remove_interactable(target: Interactable) -> void:
	_reach.remove(target)


func _try_interact() -> void:
	if state != State.MOVE or not is_on_floor():
		return
	# Это нажатие — «ОК» окна находки: соседний предмет им не берём.
	if ItemPopup.takes_interact():
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
	model.update(self)
	if lying:
		body_mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
		body_mesh.position = Vector3(0.0, 0.72, 0.0)
		return
	var k := 1.0 - exp(-18.0 * delta)
	var target_scale := Vector3.ONE
	var target_tilt := -AgeLook.stoop(stats.current_age)
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
	body_mesh.scale = body_mesh.scale.lerp(target_scale * AgeLook.body_scale(stats.current_age), k)
	body_mesh.position = Vector3(0.0, 0.9 * body_mesh.scale.y, 0.0)
	if state == State.ROLL:
		# Кувырок вперёд: полный оборот за время переката.
		body_mesh.rotation.z = -TAU * _state_time / stats.roll_duration
	else:
		body_mesh.rotation.z = lerpf(wrapf(body_mesh.rotation.z, -PI, PI), target_tilt, k)
	# Мигание в неуязвимости после удара (перекат и особые удары не мигают).
	var blink := _iframes > 0.0 and state not in [State.ROLL, State.CRITICAL] \
		and fmod(_iframes, 0.12) < 0.06
	body_mesh.visible = not blink
	model.visible = not blink
