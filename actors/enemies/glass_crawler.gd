class_name GlassCrawler
extends Dummy
## Стеклянный ползун (§6.3): желейная кучка стекла. Выдувается из мутного стекла,
## бьёт колом, который выращивает прямо из тела, как T-1000.
##
## Ответы на обязательные вопросы: стойкость низкая (желе мнётся), спины нет
## (удар в спину невозможен), кол можно парировать — он трескается, у ползуна
## «кружится голова»; добивание особое — меч в сердцевину, ползун растекается
## лужицей стекла и застывает.
##
## Может висеть на потолке каплей в засаде: с него капает стекло (подсказка §5.3).
## Сбитый стрелой — падает и лежит оглушённый; герой прошёл под ним — падает на героя.

const HEAT_TIME := 0.5
const BUBBLE_TIME := 0.4
const DROP_TIME := 0.4
const SPIKE_GROW := 0.12
const SPIKE_RETRACT := 0.25
const SPIKE_ORIGIN_X := 0.25
const PUDDLE_COLOR := Color(0.75, 0.86, 0.95, 0.55)
## Насколько близко по X герой должен подойти под висящего ползуна, чтобы тот упал.
const DROP_SENSE := 3.0
const DROP_SPEED := 12.0
const SHOT_FALL_DAMAGE := 15.0
const SHOT_STUN_TIME := 1.6
## Сколько удар телом остаётся опасным после приземления на героя.
const SLAM_LINGER := 0.15

## Мутное стекло, из которого ползун выдувается.
@export var source_glass: NodePath
## Как близко герой должен подойти к стеклу, чтобы ползун начал выдуваться.
@export var wake_distance := 3.0
@export var spike_length := 2.6
## Висит на потолке в засаде.
@export var ceiling_hang := false

var _glass: GlassSurface
var _emerge_t := -1.0
var _bubble_pos := Vector3.ZERO
var _ground_pos := Vector3.ZERO
var _spike_broken := false
var _wobble := 0.0
var _attack_shape: BoxShape3D
var _hanging := false
## Падает на героя телом (засада с потолка).
var _dropping := false
var _slam_left := 0.0
var _drips: CPUParticles3D

@onready var spike: Node3D = $Visual/Spike
@onready var attack_shape_node: CollisionShape3D = $Visual/AttackHitbox/Shape
@onready var side_left: MeshInstance3D = $Visual/Body/SideLeft
@onready var side_right: MeshInstance3D = $Visual/Body/SideRight


func _ready() -> void:
	super()
	side_left.material_override = _material
	side_right.material_override = _material
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.rim_enabled = true
	_material.rim = 0.6
	_attack_shape = attack_shape_node.shape.duplicate()
	attack_shape_node.shape = _attack_shape
	spike.visible = false
	_glass = get_node_or_null(source_glass) as GlassSurface
	if ceiling_hang:
		_start_hanging()
	elif dormant:
		visible = false


# --- Появление: стекло нагревается → шарик → падение → желейная кучка -------

func _wake_check(delta: float) -> void:
	_find_player()
	if _hanging:
		if _player and not _player.is_dead():
			var d := _player.global_position - global_position
			if absf(d.x) < DROP_SENSE and d.y < 0.0:
				_drop(false)
		return
	if _emerge_t < 0.0:
		if _should_wake():
			_start_emerge()
		return
	_emerge_t += delta
	var t := _emerge_t
	if t < HEAT_TIME:
		if _glass:
			_glass.heat(t / HEAT_TIME)
	elif t < HEAT_TIME + BUBBLE_TIME:
		# Из поверхности стекла раздувается светящийся шарик.
		visible = true
		var k := (t - HEAT_TIME) / BUBBLE_TIME
		global_position = _bubble_pos
		_set_blob(Vector3.ONE * lerpf(0.1, 0.75, k), false)
		_material.emission_energy_multiplier = 2.0
	elif t < HEAT_TIME + BUBBLE_TIME + DROP_TIME:
		if _glass:
			_glass.purify()
		var k := (t - HEAT_TIME - BUBBLE_TIME) / DROP_TIME
		global_position = _bubble_pos.lerp(_ground_pos, k * k)
		_set_blob(Vector3.ONE * 0.75, false)
	else:
		_finish_emerge()


func _should_wake() -> bool:
	if _glass and _glass._broken:
		return true
	if _player == null or _player.is_dead():
		return false
	var anchor := _glass.global_position if _glass else global_position
	var d := _player.global_position - anchor
	return absf(d.x) < wake_distance and absf(d.y) < 2.5


func _start_emerge() -> void:
	_emerge_t = 0.0 if _glass and not _glass._broken else HEAT_TIME
	var anchor := _glass.global_position if _glass else global_position
	_bubble_pos = Vector3(anchor.x, anchor.y - 0.3, anchor.z + 0.35)
	_ground_pos = Vector3(anchor.x, _origin.y, 0.0)


func _finish_emerge() -> void:
	global_position = _ground_pos
	reset_physics_interpolation()
	_set_blob(Vector3.ONE, true)
	_material.emission_energy_multiplier = 0.0
	if _glass:
		_glass.heat(0.0)
	# Шлепок о землю — кучка сплющивается и сразу идёт в атаку, как засада.
	body_mesh.scale = Vector3(1.4, 0.55, 1.4)
	on_revealed()


func _set_blob(blob_scale: Vector3, with_sides: bool) -> void:
	body_mesh.scale = blob_scale
	side_left.visible = with_sides
	side_right.visible = with_sides


# --- Засада на потолке ------------------------------------------------------

func _start_hanging() -> void:
	_hanging = true
	state = State.DORMANT
	visible = true
	# Капля вниз: тельце вытянуто и перевёрнуто.
	_set_blob(Vector3(0.75, 1.35, 0.75), false)
	body_mesh.rotation.z = PI
	_drips = CPUParticles3D.new()
	_drips.amount = 3
	_drips.lifetime = 1.8
	_drips.direction = Vector3.DOWN
	_drips.spread = 0.0
	_drips.gravity = Vector3(0.0, -14.0, 0.0)
	_drips.initial_velocity_min = 0.5
	_drips.initial_velocity_max = 1.0
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.05
	drop_mesh.height = 0.12
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.75, 0.9, 1.0, 0.8)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.emission_enabled = true
	drop_mat.emission = Color(0.6, 0.85, 1.0)
	drop_mat.emission_energy_multiplier = 1.5
	drop_mesh.material = drop_mat
	_drips.mesh = drop_mesh
	_drips.position.y = -0.1
	add_child(_drips)


## shot — сбит стрелой: падает оглушённым. Иначе — падает на героя.
func _drop(shot: bool) -> void:
	_hanging = false
	_drips.emitting = false
	_set_blob(Vector3.ONE, true)
	body_mesh.rotation = Vector3.ZERO
	velocity = Vector3(0.0, -DROP_SPEED, 0.0)
	_find_player()
	if _player:
		facing = signf(_player.global_position.x - global_position.x)
	if shot:
		health.take_damage(SHOT_FALL_DAMAGE)
		_flash = 0.15
		_set_state(State.KNOCKDOWN)
		# Оглушён дольше обычного сбивания с ног.
		_state_time = knockdown_time - SHOT_STUN_TIME
	else:
		_dropping = true
		_set_state(State.RECOVER)


func _on_hurt(hitbox: Hitbox) -> void:
	if _hanging:
		health.take_damage(hitbox.damage)
		_drop(true)
		return
	super(hitbox)


# --- Кол ----------------------------------------------------------------------

func _on_attack_started() -> void:
	_spike_broken = false


func on_parried() -> bool:
	var parried := super()
	if parried:
		# Кол трескается и осыпается.
		_spike_broken = true
		spike.visible = false
		var tip := spike.global_position + Vector3(facing * 1.0, 0.0, 0.3)
		HitSpark.spawn(get_parent(), tip, Color(0.8, 0.95, 1.0), 24)
	return parried


func _update_extra(delta: float) -> void:
	if _dropping:
		# Падение на героя: бьёт всем телом и ещё мгновение после приземления.
		spike.visible = false
		_attack_shape.size = Vector3(1.1, 1.0, 1.0)
		attack_shape_node.position = Vector3(0.0, 0.3, 0.0)
		attack_hitbox.active = true
		if is_on_floor():
			if _slam_left <= 0.0:
				_slam_left = SLAM_LINGER
				Events.camera_shake_requested.emit(0.25, 0.2)
			_slam_left -= delta
			if _slam_left <= 0.0:
				_dropping = false
				attack_hitbox.active = false
		return
	var length := _spike_length_now()
	spike.visible = length > 0.05
	spike.scale = Vector3(1.0, maxf(length, 0.01), 1.0)
	_attack_shape.size = Vector3(maxf(length, 0.1), 0.5, 1.0)
	attack_shape_node.position = Vector3(SPIKE_ORIGIN_X + length * 0.5, 0.42, 0.0)


func _spike_length_now() -> float:
	if _spike_broken:
		return 0.0
	match state:
		State.ATTACK:
			return spike_length * clampf(_state_time / SPIKE_GROW, 0.0, 1.0)
		State.RECOVER:
			return spike_length * clampf(1.0 - _state_time / SPIKE_RETRACT, 0.0, 1.0)
	return 0.0


# --- Тельце -------------------------------------------------------------------

func _update_pose(delta: float) -> void:
	if state in [State.DEAD, State.DORMANT]:
		return
	_wobble += delta * (6.0 if absf(velocity.x) > 0.1 else 2.5)
	var target := Vector3(1.0 + 0.06 * sin(_wobble), 1.0 - 0.08 * sin(_wobble), 1.0)
	body_mesh.rotation = Vector3.ZERO
	body_mesh.position = Vector3(0.0, 0.45, 0.0)
	match state:
		State.WINDUP:
			# Телеграф: кучка сжимается перед выбросом кола.
			var k := clampf(_state_time / windup_time, 0.0, 1.0)
			target = Vector3(1.0 + 0.2 * k, 1.0 - 0.25 * k, 1.0 + 0.2 * k)
		State.OFF_BALANCE:
			# «Кружится голова»: всё тельце кружится и качается.
			var spin := _state_time * 9.0
			body_mesh.rotation = Vector3(0.0, spin, 0.25 * sin(spin * 0.7))
			body_mesh.position = Vector3(0.12 * cos(spin), 0.45, 0.12 * sin(spin))
			target = Vector3(1.1, 0.85 + 0.1 * sin(spin * 1.3), 1.1)
		State.KNOCKDOWN, State.CRITICAL_HIT:
			target = Vector3(1.3, 0.6, 1.3)
	body_mesh.scale = body_mesh.scale.lerp(target, 1.0 - exp(-14.0 * delta))


## Смерть: ползун растекается лужицей стекла и застывает — лужица остаётся.
func _on_died() -> void:
	_set_state(State.DEAD)
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	attack_hitbox.active = false
	spike.visible = false
	body_mesh.rotation = Vector3.ZERO
	var tween := create_tween().set_parallel()
	tween.tween_property(body_mesh, "scale", Vector3(2.2, 0.12, 1.6), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_mesh, "position", Vector3(0.0, 0.06, 0.0), 0.5)
	tween.tween_property(side_left, "scale", Vector3(1.6, 0.2, 1.4), 0.5)
	tween.tween_property(side_right, "scale", Vector3(1.6, 0.2, 1.4), 0.5)
	tween.chain().tween_callback(_freeze)


func _freeze() -> void:
	body_color = PUDDLE_COLOR
	_material.albedo_color = PUDDLE_COLOR
	_material.emission_energy_multiplier = 0.0
	_material.roughness = 0.05
	_material.metallic = 0.3
	set_physics_process(false)
