class_name Vampire
extends Dummy
## Вампир (§6.3, 2026-11-09): человек на манекене героя — бледный, в плаще, с красными глазами,
## бьёт когтями. Класс VAMPIRE: Блик и прочая слепота не ослепляют его, а дезориентируют —
## он шатается, и его можно добить спереди (§6.2).
##
## «Мышь» — превращение в огромную летучую мышь (как в «Ван Хельсинге»), с дистанции:
## 1. Взлёт (телеграф, около секунды): глаза вспыхивают красным, он взмывает, поворачивается
##    к камере и раскрывает плащ крыльями; наверху — короткий вис.
## 2. Пике на место героя: удар телом. Уйти — перекатом или отбежать.
## 3. Удар о землю: тёмная вспышка, дым и стая мышей скрывают превращение; по земле в обе
##    стороны бежит волна — её перепрыгивают.
## 4. Мышь: набирает высоту и пикирует низко сквозь героя (swoops раз), в конце пролёта — за его
##    спиной. В замахе пике глаза мыши разгораются, она зависает; уйти — прыжком или перекатом.
## 5. Садится в облаке дыма и снова человек; на миг открыт — окно для удара.
## В облике мыши удары по ней проходят, но не сбивают; добить её и ударить в спину нельзя.

enum Move { NONE, RISE, DIVE, BURST, BAT_UP, BAT_AIM, BAT_SWOOP, BAT_LAND }

## Цвет тьмы превращения: вспышка, дым, кольцо, волна.
const DARK := Color(0.55, 0.05, 0.12)
## Взлёт: какую долю времени он раскрывает плащ и разгораются глаза.
const SPREAD_SHARE := 0.75
## Отступ от стен и потолка, куда мышь не залетает.
const ROOM_MARGIN := 1.4

@export_group("Превращение в мышь")
## Когда вообще пробует: дистанция до героя и перерыв между превращениями.
@export var bat_min_range := 3.5
@export var bat_max_range := 10.0
@export var bat_cooldown := 10.0
## Сколько ждать после того, как заметил героя, прежде чем превратиться в первый раз.
@export var bat_first_delay := 2.0
@export var rise_height := 3.2
@export var rise_time := 0.75
@export var hang_time := 0.35
@export var dive_speed := 20.0
@export var dive_damage := 28.0
@export var wave_damage := 14.0
@export var wave_speed := 9.0
@export var wave_reach := 6.0
## Пике мыши: сколько раз, на какой высоте центр тела проходит над полом (перепрыгнуть),
## скорость, замах и урон; на какой высоте мышь висит между пике.
@export var swoops := 2
@export var swoop_height := 0.55
@export var swoop_speed := 12.0
@export var swoop_windup := 0.6
@export var swoop_damage := 20.0
@export var bat_hover := 3.4
## Человек снова на земле: столько секунд открыт.
@export var land_recover := 1.1

var move := Move.NONE
var bat: GiantBat
var _move_t := 0.0
var _floor_y := 0.0
var _target := Vector3.ZERO
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _swoop_x := 0.0
var _swoops_left := 0
var _bat_wait := 0.0
var _left_x := -INF
var _right_x := INF
var _top_y := INF
var _body_hit: Hitbox
var _layer := 0
var _mask := 0
var _seen := false
## Замах и откат когтей из сцены: приём меняет их на время своих фаз.
var _windup_base := 0.0
var _recover_base := 0.0


func _init() -> void:
	creature = CreatureKind.Kind.VAMPIRE
	mannequin_look = EnemyModel.VAMPIRE
	# Нечисть: святая вода жжёт её во много раз сильнее.
	unholy = true


func _ready() -> void:
	super()
	_windup_base = windup_time
	_recover_base = recover_time
	bat = GiantBat.build(self)
	bat.visible = false
	_body_hit = Hitbox.new()
	_body_hit.name = &"BodyHit"
	_body_hit.collision_layer = 0
	_body_hit.collision_mask = attack_hitbox.collision_mask
	_body_hit.knockback = 9.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.2, 1.2)
	shape.shape = box
	shape.position.y = GiantBat.CENTER
	_body_hit.add_child(shape)
	add_child(_body_hit)


# --- Выбор: когда превращаться ------------------------------------------------------

func _chase(delta: float) -> void:
	if not _seen:
		_seen = true
		_bat_wait = bat_first_delay
	_bat_wait -= delta
	if _bat_wait <= 0.0 and _player and not _player.is_dead() and is_on_floor():
		var distance := absf(_player.global_position.x - global_position.x)
		if distance >= bat_min_range and distance <= bat_max_range:
			start_bat()
			return
	super(delta)


## Начать превращение (и из тестов). Взлёт — телеграф: красный, как любой замах.
func start_bat() -> void:
	if move != Move.NONE or state == State.DEAD:
		return
	_find_player()
	_bat_wait = bat_cooldown
	_floor_y = global_position.y
	_measure_room()
	_layer = collision_layer
	_mask = collision_mask
	# В приёме он не толкает и не упирается: летит, куда задумал.
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if _player:
		facing = signf(_player.global_position.x - global_position.x) if _player.global_position.x != global_position.x else facing
	_turn_t = -1.0
	_from = global_position
	_set_move(Move.RISE)
	_set_state(State.WINDUP)
	windup_time = rise_time + hang_time
	Sfx.play(&"vampire_screech", global_position)
	Sfx.play(&"bat_wings", global_position)


func _set_move(next: Move) -> void:
	move = next
	_move_t = 0.0


## Стены и потолок вокруг: мышь не вылетает из комнаты.
func _measure_room() -> void:
	var space := get_world_3d().direct_space_state
	var at := global_position + Vector3(0.0, 1.5, 0.0)
	_left_x = _ray(space, at, at + Vector3(-30.0, 0.0, 0.0)).x + ROOM_MARGIN
	_right_x = _ray(space, at, at + Vector3(30.0, 0.0, 0.0)).x - ROOM_MARGIN
	_top_y = _ray(space, at, at + Vector3(0.0, 30.0, 0.0)).y - ROOM_MARGIN - GiantBat.CENTER


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.position if hit else to


## Пол под точкой (куда бить пике, если герой в прыжке).
func _ground_at(x: float, from_y: float) -> float:
	var hit := _ray(get_world_3d().direct_space_state, Vector3(x, from_y + 0.5, 0.0), Vector3(x, from_y - 20.0, 0.0))
	return maxf(hit.y, _floor_y - 6.0)


func _clamp_x(x: float) -> float:
	return clampf(x, _left_x, _right_x) if _left_x < _right_x else x


# --- Каждый кадр ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if move == Move.NONE:
		super(delta)
		return
	_state_time += delta
	_move_t += delta
	_find_player()
	match move:
		Move.RISE: _rise()
		Move.DIVE: _dive(delta)
		Move.BURST: _burst_out()
		Move.BAT_UP: _bat_up()
		Move.BAT_AIM: _bat_aim(delta)
		Move.BAT_SWOOP: _bat_swoop()
		Move.BAT_LAND: _bat_land()
	_update_material(delta)
	if model:
		model.update(delta)
		_pose_model(delta)
	if bat.visible:
		# Своё тело мыши тёмное: от врага берётся только красный замаха и белая вспышка удара.
		if _flash > 0.0:
			bat.glow(Color.WHITE, 2.0)
		elif state == State.WINDUP:
			var t := clampf(_state_time / windup_time, 0.0, 1.0)
			bat.glow(Color(0.8, 0.08, 0.05), t * 0.45)
		else:
			bat.glow(Color.BLACK, 0.0)


func _rise() -> void:
	var k := clampf(_move_t / rise_time, 0.0, 1.0)
	var up := 1.0 - pow(1.0 - k, 3.0)
	# Чуть отступает назад, пока взмывает; наверху — вис и лёгкое покачивание.
	var height := minf(rise_height, _top_y - _floor_y)
	global_position = Vector3(_clamp_x(_from.x - facing * 0.8 * up), _floor_y + height * up, 0.0)
	if _move_t >= rise_time:
		global_position.y += sin((_move_t - rise_time) * 12.0) * 0.05
	if _move_t >= rise_time + hang_time:
		var aim := _player.global_position if _player else global_position + Vector3(facing * 4.0, 0.0, 0.0)
		_target = Vector3(_clamp_x(aim.x), _ground_at(aim.x, aim.y), 0.0)
		facing = signf(_target.x - global_position.x) if _target.x != global_position.x else facing
		_from = global_position
		_set_move(Move.DIVE)
		_set_state(State.ATTACK)
		_body_hit.damage = dive_damage
		_body_hit.active = true
		Sfx.play(&"sword_swing", global_position, 4.0)


func _dive(delta: float) -> void:
	var to := _target - global_position
	var step := dive_speed * delta
	if to.length() <= step:
		global_position = _target
		_impact()
		return
	global_position += to.normalized() * step


## Удар о землю: тьма скрывает превращение; волна в обе стороны.
func _impact() -> void:
	_body_hit.active = false
	_set_move(Move.BURST)
	_set_state(State.RECOVER)
	recover_time = 9.0
	Events.camera_shake_requested.emit(0.8, 0.35)
	HitStop.stop(0.06)
	Sfx.play(&"sword_block", global_position, 6.0)
	Sfx.play(&"bat_burst", global_position)
	DarkBurst.spawn(get_parent(), global_position, 1.0)
	for dir: float in [-1.0, 1.0]:
		_spawn_wave(dir)


## Из дыма вырастает мышь — человек исчез под вспышкой.
func _burst_out() -> void:
	if _move_t >= 0.05 and model.visible:
		model.visible = false
		bat.visible = true
		bat.scale = Vector3.ONE * 0.3
		bat.rotation = Vector3.ZERO
	if bat.visible:
		bat.scale = Vector3.ONE * lerpf(0.3, 1.0, clampf((_move_t - 0.05) / 0.3, 0.0, 1.0))
	if _move_t >= 0.45:
		_swoops_left = swoops
		_start_climb()


## Набрать высоту на стороне, откуда удобно пикировать сквозь героя.
func _start_climb() -> void:
	_from = global_position
	var px := _player.global_position.x if _player else global_position.x
	var side := signf(global_position.x - px)
	if side == 0.0:
		side = -facing
	_to = Vector3(_clamp_x(px + side * 5.0), minf(_floor_y + bat_hover, _top_y) - GiantBat.CENTER, 0.0)
	_set_move(Move.BAT_UP)
	_set_state(State.RECOVER)


func _bat_up() -> void:
	var time := 0.8
	var k := smoothstep(0.0, 1.0, _move_t / time)
	var last := global_position
	global_position = _from.lerp(_to, k) + Vector3(0.0, sin(k * PI) * 0.8, 0.0)
	bat.steer((global_position - last) / maxf(get_physics_process_delta_time(), 0.001), get_physics_process_delta_time())
	bat.flap = 1.0
	if _move_t >= time:
		_set_move(Move.BAT_AIM)
		_set_state(State.WINDUP)
		windup_time = swoop_windup
		Sfx.play(&"vampire_screech", global_position, -3.0)


## Замах пике: зависла, глаза разгораются, чуть отпрянула.
func _bat_aim(delta: float) -> void:
	var k := clampf(_move_t / swoop_windup, 0.0, 1.0)
	bat.eyes_flare = k
	bat.flap = 1.0 - k * 0.6
	var px := _player.global_position.x if _player else global_position.x
	var away := signf(global_position.x - px)
	global_position = _to + Vector3(away * 0.4 * k, 0.25 * k, 0.0)
	bat.steer(Vector3.ZERO, delta)
	if _move_t >= swoop_windup:
		_from = global_position
		_swoop_x = px
		_to = Vector3(_clamp_x(px - away * 5.0), _from.y, 0.0)
		_set_move(Move.BAT_SWOOP)
		_set_state(State.ATTACK)
		_body_hit.damage = swoop_damage
		Sfx.play(&"bat_wings", global_position, 3.0)


## Пике: по параболе, ниже всего — над героем (центр тела на swoop_height над полом).
func _bat_swoop() -> void:
	var span := absf(_to.x - _from.x)
	var time := maxf(span / swoop_speed, 0.3)
	var k := clampf(_move_t / time, 0.0, 1.0)
	var last := global_position
	var x := lerpf(_from.x, _to.x, k)
	var reach := maxf(absf(_from.x - _swoop_x), absf(_to.x - _swoop_x))
	var u := clampf((x - _swoop_x) / maxf(reach, 0.1), -1.0, 1.0)
	var low := _floor_y + swoop_height - GiantBat.CENTER
	global_position = Vector3(x, low + (_from.y - low) * u * u, 0.0)
	var delta := get_physics_process_delta_time()
	bat.steer((global_position - last) / maxf(delta, 0.001), delta)
	bat.flap = 0.35
	bat.eyes_flare = 1.0 - k
	# Бьёт, пока низко: наверху дуги мышь не опасна.
	_body_hit.active = global_position.y + GiantBat.CENTER < _floor_y + 1.8
	if k >= 1.0:
		_body_hit.active = false
		_swoops_left -= 1
		if _swoops_left > 0:
			_to = global_position
			_set_move(Move.BAT_AIM)
			_set_state(State.WINDUP)
			windup_time = swoop_windup
		else:
			_from = global_position
			_to = Vector3(global_position.x, _floor_y, 0.0)
			_set_move(Move.BAT_LAND)
			_set_state(State.RECOVER)


## Опускается и в облаке дыма снова человек.
func _bat_land() -> void:
	var time := 0.6
	var k := clampf(_move_t / time, 0.0, 1.0)
	var last := global_position
	global_position = _from.lerp(_to, k * k)
	var delta := get_physics_process_delta_time()
	bat.steer((global_position - last) / maxf(delta, 0.001), delta)
	if k >= 1.0:
		DarkBurst.spawn(get_parent(), global_position, 0.6)
		Sfx.play(&"bat_burst", global_position, -4.0)
		_end_move()
		recover_time = land_recover
		_set_state(State.RECOVER)


## Снова человек на ногах: модель, столкновения, поза.
func _end_move() -> void:
	move = Move.NONE
	_body_hit.active = false
	bat.visible = false
	bat.eyes_flare = 0.0
	if model:
		model.visible = true
		model.spread = 0.0
		model.eyes_flare = 0.0
		model.lean.rotation = Vector3.ZERO
	collision_layer = _layer
	collision_mask = _mask
	velocity = Vector3.ZERO
	visual.rotation = Vector3(0.0, 0.0 if facing > 0.0 else PI, 0.0)
	visual.reset_physics_interpolation()
	windup_time = _windup_base
	recover_time = _recover_base


## Манекен в приёме: к камере на взлёте, головой вперёд в пике; плащ и глаза.
func _pose_model(delta: float) -> void:
	var to_camera := -PI * 0.5
	var side := 0.0 if facing > 0.0 else PI
	match move:
		Move.RISE:
			var k := clampf(_move_t / (rise_time * SPREAD_SHARE), 0.0, 1.0)
			model.spread = smoothstep(0.0, 1.0, k)
			model.eyes_flare = smoothstep(0.1, 0.8, k)
			visual.rotation.y = lerp_angle(side, to_camera, smoothstep(0.0, 1.0, k))
			model.lean.rotation.z = 0.0
		Move.DIVE:
			model.spread = 1.0
			model.eyes_flare = 1.0
			visual.rotation.y = lerp_angle(visual.rotation.y, side, 1.0 - exp(-25.0 * delta))
			# Головой вперёд, вниз — по направлению пике.
			var dir := (_target - _from).normalized()
			model.lean.rotation.z = lerp_angle(model.lean.rotation.z, -clampf(PI * 0.5 + atan2(dir.y, absf(dir.x)), 0.0, 1.4), 1.0 - exp(-20.0 * delta))


## Клип манекена в приёме: в воздухе — поджатые ноги прыжка.
func _model_pose() -> StringName:
	return &"Jump" if move in [Move.RISE, Move.DIVE] else &""


## Волна по полу от удара: её перепрыгивают.
func _spawn_wave(dir: float) -> void:
	var wave := Hitbox.new()
	wave.collision_layer = 0
	wave.collision_mask = attack_hitbox.collision_mask
	wave.damage = wave_damage
	wave.knockback = 5.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.5, 1.2)
	shape.shape = box
	shape.position.y = 0.25
	wave.add_child(shape)
	var mesh := MeshInstance3D.new()
	var slab := PrismMesh.new()
	slab.size = Vector3(0.8, 0.45, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.02, 0.03)
	material.emission_enabled = true
	material.emission = DARK
	material.emission_energy_multiplier = 1.0
	slab.material = material
	mesh.mesh = slab
	mesh.position.y = 0.22
	wave.add_child(mesh)
	get_parent().add_child(wave)
	wave.global_position = Vector3(global_position.x + dir * 0.9, global_position.y, 0.0)
	wave.active = true
	var end := _clamp_x(wave.global_position.x + dir * wave_reach)
	var time := absf(end - wave.global_position.x) / wave_speed
	var tween := wave.create_tween()
	tween.tween_property(wave, "global_position:x", end, maxf(time, 0.05))
	tween.parallel().tween_property(mesh, "scale", Vector3(1.0, 0.3, 1.0), maxf(time, 0.05))
	tween.tween_callback(wave.queue_free)


# --- Защита и прерывания ----------------------------------------------------------

## В приёме удары проходят, но не сбивают: в воздухе и в облике мыши стойки нет.
func _on_hurt(hitbox: Hitbox) -> void:
	if move == Move.NONE or state == State.DEAD:
		super(hitbox)
		return
	last_weapon = hitbox.weapon_type
	health.take_damage(hitbox.damage)
	_flash = 0.12
	if health.is_dead():
		return
	_add_bleed(hitbox.bleed)
	Sfx.play(&"enemy_hurt", global_position)


func on_parried() -> bool:
	return false if move != Move.NONE else super()


func can_be_backstabbed(from_x: float) -> bool:
	return false if move != Move.NONE else super(from_x)


func can_be_riposted() -> bool:
	return false if move != Move.NONE else super()


## Всё, что выводит из приёма извне (смерть, слепота, сцена), сначала возвращает облик человека.
func _set_state(new_state: State) -> void:
	if move != Move.NONE and new_state in [State.DEAD, State.BLINDED, State.CRITICAL_HIT, State.STAGGER, State.KNOCKDOWN, State.OFF_BALANCE]:
		_end_move()
	super(new_state)
