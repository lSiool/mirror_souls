class_name Statuses
extends Node
## Состояния от склянок, огненных стрел и огня (§6.2) — на враге или на герое, общий компонент.
## - яд и горение — урон каждые полсекунды;
## - «разъедено» (кислота) — по носителю бьют больнее (Health.taken_mult) и сильнее сбивают стойкость;
## - смола — носитель еле двигается, замах и удары медленнее (speed_mult, time_mult);
## - огонь по смоле — взрыв (TarBlast), смола сгорает;
## - слепота (Блик, ловушки, расходники) — общий эффект: как её переживает враг, решает его класс
##   (CreatureKind), здесь — только время и блёстки у глаз. Герой пока не слепнет (позже).
## Видно по носителю: язык пламени, капли смолы, пузыри яда, шипение кислоты.

signal started(id: StringName)
signal ended(id: StringName)

const POISON := &"poison"
const BURNING := &"burning"
const CORRODED := &"corroded"
const TAR := &"tar"
const BLIND := &"blind"

## Урон в секунду от яда и огня — черновик.
const DPS := {POISON: 4.0, BURNING: 6.0}
const TICK := 0.5
const CORRODED_DAMAGE := 1.35
const CORRODED_POISE := 1.5
## Смола: доля скорости и темпа ударов. Герой вязнет мягче врага (Player.TAR_*).
const TAR_SPEED := 0.15
const TAR_TEMPO := 0.4
## Стандартная слепота (§6.2): у человека — секунда отшатывания и три — трёт глаза.
## Источник вешает её на это время; класс и сопротивление врага укорачивают (Dummy._resist_status).
const BLIND_TIME := 4.0
## Подкраска тела носителя (враги — Dummy._update_material).
const TINT := {
	POISON: Color(0.45, 0.18, 0.55),
	BURNING: Color(1.0, 0.45, 0.1),
	CORRODED: Color(0.55, 0.85, 0.15),
	TAR: Color(0.04, 0.035, 0.03),
}

## Чьё здоровье: урон от яда и огня, множитель «разъедено».
var health: Health
## Высота носителя: где горит пламя и откуда капает смола.
var height := 1.8
## Сопротивление носителя: (id, секунды) → сколько секунд на самом деле; 0 — не подействовало.
## Так любой источник просто вешает состояние, а невосприимчивость и привыкание — у носителя.
var resist: Callable

var _left := {}
var _tick := 0.0
var _fx := {}


func _init(of: Health = null, body_height := 1.8) -> void:
	name = "Statuses"
	health = of
	height = body_height


func has(id: StringName) -> bool:
	return _left.has(id)


func time_left(id: StringName) -> float:
	return _left.get(id, 0.0)


## Повесить состояние на time секунд; уже висит — продлевается до большего.
func apply(id: StringName, time: float) -> void:
	if time <= 0.0 or (health and health.is_dead()):
		return
	if id == BURNING and has(TAR):
		_tar_ignited()
		return
	if resist.is_valid():
		time = resist.call(id, time)
		if time <= 0.0:
			return
	var fresh := not _left.has(id)
	_left[id] = maxf(_left.get(id, 0.0), time)
	if fresh:
		_start_fx(id)
		_sync_health()
		started.emit(id)


func remove(id: StringName) -> void:
	if not _left.has(id):
		return
	_left.erase(id)
	_stop_fx(id)
	_sync_health()
	ended.emit(id)


func clear() -> void:
	for id: StringName in _left.keys():
		remove(id)


func speed_mult() -> float:
	return TAR_SPEED if has(TAR) else 1.0


func time_mult() -> float:
	return TAR_TEMPO if has(TAR) else 1.0


func poise_mult() -> float:
	return CORRODED_POISE if has(CORRODED) else 1.0


## Цвет тела с учётом состояний и сила свечения (для материала носителя).
func tint(color: Color) -> Color:
	for id: StringName in [TAR, CORRODED, POISON, BURNING]:
		if has(id):
			var k := 0.85 if id == TAR else 0.45
			color = color.lerp(Color(TINT[id], color.a), k)
	return color


func glow() -> float:
	if has(BURNING):
		return 1.2
	if has(CORRODED):
		return 0.4
	return 0.0


func _physics_process(delta: float) -> void:
	if _left.is_empty():
		return
	if health and health.is_dead():
		clear()
		return
	for id: StringName in _left.keys():
		_left[id] -= delta
		if _left[id] <= 0.0:
			remove(id)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var dps := 0.0
	for id: StringName in DPS:
		if has(id):
			dps += DPS[id]
	if dps > 0.0 and health:
		health.take_damage(dps * TICK)
		var carrier := get_parent() as Node3D
		if carrier:
			var color: Color = TINT[BURNING] if has(BURNING) else TINT[POISON]
			HitSpark.spawn(carrier.get_parent(), carrier.global_position + Vector3(0.0, height * 0.6, 0.3), color, 5)


func _sync_health() -> void:
	if health:
		health.taken_mult = CORRODED_DAMAGE if has(CORRODED) else 1.0


## Огонь коснулся смолы на носителе: взрыв, смола сгорает, носитель горит.
func _tar_ignited() -> void:
	remove(TAR)
	var carrier := get_parent() as Node3D
	if carrier == null or not carrier.is_inside_tree():
		return
	TarBlast.explode.call_deferred(carrier.get_parent(), carrier.global_position + Vector3(0.0, height * 0.4, 0.0))
	apply(BURNING, 2.0)


# --- Вид --------------------------------------------------------------------

func _start_fx(id: StringName) -> void:
	var carrier := get_parent() as Node3D
	if carrier == null:
		return
	var fx: Node3D
	match id:
		BURNING:
			var flame := Flame.make(Vector2(height * 0.55, height * 0.95))
			flame.position = Vector3(0.0, height * 0.15, 0.25)
			fx = flame
		TAR:
			fx = _drips(Color(0.03, 0.025, 0.02), Vector3(0.0, -9.0, 0.0), 0.06, 10)
		POISON:
			fx = _drips(Color(0.6, 0.25, 0.75, 0.7), Vector3(0.0, 1.2, 0.0), 0.08, 8)
		CORRODED:
			fx = _drips(Color(0.6, 1.0, 0.2, 0.8), Vector3(0.0, 2.0, 0.0), 0.05, 12)
		BLIND:
			# Белые блёстки у глаз: свет ещё режет.
			fx = _drips(Color(1.0, 0.97, 0.85, 0.9), Vector3(0.0, 0.3, 0.0), 0.04, 8, 0.88, 0.08)
	if fx:
		carrier.add_child(fx)
		_fx[id] = fx


func _stop_fx(id: StringName) -> void:
	var fx: Node3D = _fx.get(id)
	_fx.erase(id)
	if fx == null or not is_instance_valid(fx):
		return
	if fx is Flame:
		var tween := fx.create_tween()
		tween.tween_property(fx, "fade", 0.0, 0.3)
		tween.tween_callback(fx.queue_free)
	else:
		(fx as CPUParticles3D).emitting = false
		get_tree().create_timer(1.0).timeout.connect(fx.queue_free)


## Капли, пузыри или шипение вокруг носителя; at — доля роста, где их середина, spread — размах по росту.
func _drips(color: Color, gravity: Vector3, size: float, amount: int, at := 0.5, spread := 0.35) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var speck := SphereMesh.new()
	speck.radius = size * 0.5
	speck.height = size
	speck.radial_segments = 6
	speck.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.1
	material.metallic = 0.3
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(color, 1.0)
		material.emission_energy_multiplier = 0.8
	speck.material = material
	particles.mesh = speck
	particles.amount = amount
	particles.lifetime = 0.7
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.3, height * spread, 0.2)
	particles.position = Vector3(0.0, height * at, 0.2)
	particles.gravity = gravity
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.5
	particles.spread = 180.0
	return particles
