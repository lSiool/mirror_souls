class_name FlyingShard
extends AnimatableBody3D
## Глыба стекла нестабильного отражения (§8.11, 2026-11-11): дорожки там нет — путь складывается
## из кусков, которые летят герою навстречу, на миг встают на место и рассыпаются за спиной.
## Место глыбы — где она стоит в сцене; до того она висит в стороне (from) и прилетает, когда герой
## подошёл на arrive_dist. Когда до неё доходит фронт схлопывания (RunLevel) — трескается и
## рассыпается. Без уровня-забега в комнате просто стоит.

enum Phase { AWAY, ARRIVING, HERE, CRACKING, GONE }

const SHADER := preload("res://effects/shaders/pearl_glass.gdshader")
const TINT := Color(0.75, 0.86, 1.0)
const SHAKE := 0.04

@export var size := Vector3(6.0, 0.6, 3.0)
## Откуда прилетает — сдвиг от своего места.
@export var from := Vector3(18.0, 7.0, -9.0)
## Герой ближе этого по x к ближнему краю — глыба летит на место.
@export var arrive_dist := 28.0
@export var arrive_time := 0.9
## Сколько трескается, прежде чем рассыпаться.
@export var warn_time := 0.5
## Стоит с самого начала (стартовая и финишная площадки).
@export var always_here := false

var phase := Phase.AWAY

var _rest: Transform3D
var _start: Transform3D
var _t := 0.0
var _shape: CollisionShape3D
var _look: Node3D
var _material: ShaderMaterial
var _player: Player
var _run: RunLevel


func _ready() -> void:
	add_to_group(&"flying_shard")
	sync_to_physics = false
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	add_child(_shape)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	# Узор у каждой глыбы свой, но один и тот же от запуска к запуску.
	var seed_value := float(absi(hash(name)) % 1000) / 1000.0
	_material.set_shader_parameter(&"seed", seed_value)
	_look = Node3D.new()
	add_child(_look)
	var top := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = size
	slab.material = _material
	top.mesh = slab
	_look.add_child(top)
	# Низ — обломанный клин: глыба, а не доска.
	var under := MeshInstance3D.new()
	var wedge := PrismMesh.new()
	wedge.size = Vector3(size.x * 0.8, size.y * 2.2 + size.x * 0.12, size.z * 0.7)
	wedge.left_to_right = 0.2 + seed_value * 0.6
	wedge.material = _material
	under.mesh = wedge
	under.rotation.z = PI
	under.position.y = -size.y * 0.5 - wedge.size.y * 0.5
	_look.add_child(under)
	_rest = global_transform
	if always_here:
		phase = Phase.HERE
		return
	var spin := Basis.from_euler(Vector3(seed_value * 2.0 - 1.0, seed_value * 3.0, 1.2 - seed_value * 2.4))
	_start = Transform3D(_rest.basis * spin, _rest.origin + from)
	global_transform = _start
	_shape.disabled = true


func _physics_process(delta: float) -> void:
	if phase == Phase.GONE:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		_run = get_tree().get_first_node_in_group(&"run_level") as RunLevel
		if _player == null:
			return
	_t += delta
	match phase:
		Phase.AWAY:
			if _player.global_position.x > _rest.origin.x - size.x * 0.5 - arrive_dist:
				phase = Phase.ARRIVING
				_t = 0.0
				_shape.disabled = false
		Phase.ARRIVING:
			var k := clampf(_t / arrive_time, 0.0, 1.0)
			# Быстро подлетает и мягко встаёт на место.
			global_transform = _start.interpolate_with(_rest, 1.0 - pow(1.0 - k, 3.0))
			if k >= 1.0:
				global_transform = _rest
				phase = Phase.HERE
		Phase.HERE:
			if _run and _run.running and _run.front_x >= _rest.origin.x - size.x * 0.5:
				phase = Phase.CRACKING
				_t = 0.0
				Sfx.play(&"glass_crack", global_position, -8.0)
		Phase.CRACKING:
			var k := clampf(_t / maxf(warn_time, 0.01), 0.0, 1.0)
			_material.set_shader_parameter(&"crack", k)
			_look.position = Vector3(randf_range(-SHAKE, SHAKE), randf_range(-SHAKE, SHAKE), 0.0) * k
			if k >= 1.0:
				_shatter()


func is_standing() -> bool:
	return phase in [Phase.HERE, Phase.CRACKING]


func _shatter() -> void:
	phase = Phase.GONE
	_shape.set_deferred(&"disabled", true)
	_look.visible = false
	Sfx.play(&"glass_break", global_position, -8.0)
	HitSpark.spawn(get_parent(), global_position, TINT, 22)
