class_name TrapTrigger
extends Area3D
## Спуск ловушки (§8.14): нажимная плита или растяжка. Наступил герой или враг — срабатывают все действия
## из `effects` (узлы с методом `fire()`: ArrowLauncher, SwingBlade…). Спустить можно и нарочно, издали:
## удар, стрела, брошенный нож попадают в свой Hurtbox спуска — тогда ловушка бьёт впустую или по врагу.
## Плита щёлкает и через rearm_time взводится снова. Растяжка рвётся один раз — до отдыха у осколка
## (комната перезагружается). Нить растяжки чуть блестит, только когда камера проходит нужный угол
## (wire_glint.gdshader): заметить можно, если смотреть.
## Узел стоит на полу посередине спуска.

signal fired

enum Kind { PLATE, WIRE }

const LAYER_PLAYER := 1 << 1
## Хёртбоксы врагов: в этот слой бьют меч, стрелы и брошенное (Hitbox, Arrow, Thrown).
const LAYER_HITTABLE := 1 << 2
const GLINT := preload("res://world/traps/wire_glint.gdshader")

@export var kind := Kind.PLATE
## Действия ловушки (узлы с методом fire()).
@export var effects: Array[NodePath] = []
## Плита: ширина по x и глубина по z. Растяжка: глубина нити по z (ширина хода).
@export var width := 1.2
@export var depth := 2.0
## Высота нити над полом.
@export var wire_height := 0.32
## Через сколько секунд плита взводится снова.
@export var rearm_time := 3.0
@export var plate_color := Color(0.3, 0.28, 0.25)

var armed := true

var _rearm_t := 0.0
var _plate: MeshInstance3D
var _wire: MeshInstance3D


func _ready() -> void:
	add_to_group(&"trap")
	collision_layer = 0
	collision_mask = LAYER_PLAYER | LAYER_HITTABLE
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if kind == Kind.PLATE:
		box.size = Vector3(width, 0.4, depth)
		shape.position.y = 0.2
	else:
		# Нить ловит ноги: перепрыгнул выше полуметра — не задел.
		box.size = Vector3(0.3, 0.4, depth)
		shape.position.y = wire_height
	shape.shape = box
	add_child(shape)
	var hurtbox := Hurtbox.new()
	hurtbox.name = &"Hurtbox"
	hurtbox.collision_layer = LAYER_HITTABLE
	hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape3D.new()
	var hurt_box := BoxShape3D.new()
	hurt_box.size = Vector3(width, 0.25, 1.2) if kind == Kind.PLATE else Vector3(0.35, 0.5, 1.2)
	hurt_shape.shape = hurt_box
	hurt_shape.position.y = 0.12 if kind == Kind.PLATE else wire_height
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	hurtbox.hurt.connect(func(_hitbox: Hitbox) -> void: trip())
	if kind == Kind.PLATE:
		_build_plate()
	else:
		_build_wire()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if armed or kind != Kind.PLATE:
		return
	_rearm_t -= delta
	if _rearm_t <= 0.0:
		armed = true
		_plate.position.y = 0.03


## Спустить ловушку: плита щёлкает, нить рвётся, действия срабатывают.
func trip() -> void:
	if not armed:
		return
	armed = false
	Sfx.play(&"trap_click", global_position)
	if kind == Kind.PLATE:
		_rearm_t = rearm_time
		_plate.position.y = 0.0
	else:
		_wire.visible = false
	# Отложенно: спуск приходит из сигнала физики, а действия создают снаряды и области.
	for path in effects:
		var effect := get_node_or_null(path)
		if effect and effect.has_method(&"fire"):
			effect.call_deferred(&"fire")
	fired.emit()


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_dead():
		trip()
	elif body is Dummy and (body as Dummy).state != Dummy.State.DEAD:
		trip()


## Плита чуть выше пола и чуть светлее камня вокруг, по краю тёмный шов: заметно, если приглядеться.
func _build_plate() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = plate_color
	stone.roughness = 0.85
	_plate = MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(width - 0.08, 0.06, depth - 0.08)
	slab.material = stone
	_plate.mesh = slab
	_plate.position.y = 0.03
	add_child(_plate)
	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color(0.03, 0.03, 0.03)
	var frame := MeshInstance3D.new()
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(width, 0.02, depth)
	frame_box.material = seam
	frame.mesh = frame_box
	frame.position.y = 0.005
	add_child(frame)


## Нить поперёк хода, от колышка к колышку; блеск — по углу взгляда.
func _build_wire() -> void:
	var glint := ShaderMaterial.new()
	glint.shader = GLINT
	_wire = MeshInstance3D.new()
	var thread := CylinderMesh.new()
	thread.top_radius = 0.012
	thread.bottom_radius = 0.012
	thread.height = depth
	thread.radial_segments = 6
	thread.rings = 1
	thread.material = glint
	_wire.mesh = thread
	_wire.rotation.x = PI * 0.5
	_wire.position.y = wire_height
	_wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wire)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.12, 0.09)
	for side: float in [-1.0, 1.0]:
		var peg := MeshInstance3D.new()
		var peg_box := BoxMesh.new()
		peg_box.size = Vector3(0.06, wire_height + 0.12, 0.06)
		peg_box.material = wood
		peg.mesh = peg_box
		peg.position = Vector3(0.0, (wire_height + 0.12) * 0.5, side * (depth * 0.5 + 0.03))
		add_child(peg)
