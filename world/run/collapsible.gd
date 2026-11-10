class_name Collapsible
extends StaticBody3D
## Кусок уровня-забега, который рушится за героем (§8.11): настил, крыша, балка.
## Когда его падать, решает RunLevel: фронт обрушения дошёл до ближнего края — кусок
## дрожит и раскаляется (warn_time), потом падает и гаснет. FOREVER исчезает навсегда;
## RESTORES через restore_time встаёт на место, держится stand_time и падает снова —
## как мигающая платформа: это право на одну ошибку.

enum Mode { FOREVER, RESTORES }
enum Phase { STANDING, WARNING, GONE }

const EMBER := Color(1.0, 0.42, 0.1)
const FALL_TIME := 0.9
const FALL_DEPTH := 7.0
const SHAKE := 0.05

@export var size := Vector3(3.0, 0.4, 3.0)
@export var color := Color(0.25, 0.17, 0.11)
@export var mode := Mode.FOREVER
## Сколько кусок дрожит и раскаляется перед падением — телеграф.
@export var warn_time := 0.8
@export var restore_time := 2.5
## Сколько восстановленный кусок держится до нового падения.
@export var stand_time := 2.0
## Сдвиг порога по x: «+» — падает позже, чем фронт дойдёт до ближнего края.
@export var at_offset := 0.0
## false — только вид (балка на фоне): герой сквозь него проходит.
@export var solid := true

var phase := Phase.STANDING
## Фронт уже дошёл: дальше кусок живёт сам, по своим таймерам.
var reached := false

var _t := 0.0
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _fall: Tween


func _ready() -> void:
	add_to_group(&"collapsible")
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.disabled = not solid
	add_child(_shape)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.roughness = 0.95
	_mat.emission_enabled = true
	_mat.emission = EMBER
	_mat.emission_energy_multiplier = 0.0
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	add_child(_mesh)


## Где фронт должен оказаться, чтобы кусок начал рушиться.
func trigger_x() -> float:
	return global_position.x - size.x * 0.5 + at_offset


## Фронт обрушения сейчас здесь (зовёт RunLevel каждый кадр физики).
func front_at(front_x: float) -> void:
	if not reached and front_x >= trigger_x():
		reached = true
		_start_warning()


func is_standing() -> bool:
	return phase != Phase.GONE


func _physics_process(delta: float) -> void:
	if not reached:
		return
	_t += delta
	match phase:
		Phase.WARNING:
			var k := clampf(_t / maxf(warn_time, 0.01), 0.0, 1.0)
			_mat.emission_energy_multiplier = k * 2.2
			_mesh.position = Vector3(randf_range(-SHAKE, SHAKE), randf_range(-SHAKE, SHAKE), 0.0) * k
			if _t >= warn_time:
				_collapse()
		Phase.GONE:
			if mode == Mode.RESTORES and _t >= restore_time:
				_restore()
		Phase.STANDING:
			if _t >= stand_time:
				_start_warning()


func _start_warning() -> void:
	phase = Phase.WARNING
	_t = 0.0
	Sfx.play(&"glass_crack", global_position, -6.0)


func _collapse() -> void:
	phase = Phase.GONE
	_t = 0.0
	_shape.set_deferred(&"disabled", true)
	Sfx.play(&"arrow_hit_wood", global_position)
	HitSpark.spawn(get_parent(), global_position, EMBER, 14)
	_fall = create_tween().set_parallel()
	_fall.tween_property(_mesh, "position", Vector3(0.0, -FALL_DEPTH, 0.0), FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fall.tween_property(_mesh, "rotation:z", randf_range(-0.6, 0.6), FALL_TIME)
	_fall.chain().tween_callback(func() -> void: _mesh.visible = false)


func _restore() -> void:
	phase = Phase.STANDING
	_t = 0.0
	if _fall:
		_fall.kill()
	_mesh.visible = true
	_mesh.position = Vector3.ZERO
	_mesh.rotation = Vector3.ZERO
	_mat.emission_energy_multiplier = 0.0
	_shape.set_deferred(&"disabled", not solid)
