class_name SunflowerRow
extends Node3D
## Ряд мёртвых подсолнухов (§8.13, Поля): высокие сухие стебли, тяжёлые чёрные головы.
## Все головы смотрят на focus (столб казни). Когда стоит watch_flag (рассказ о казни дослушан) —
## головы медленно, вразнобой, поворачиваются за героем.
## Узел стоит левым краем ряда на земле; rise — подъём земли на всю длину ряда (склон).

@export var length := 10.0
@export var count := 8
@export var height := 2.4
@export var rise := 0.0
@export var seed := 1
@export var focus: NodePath
@export var watch_flag: StringName

const STEM := Color(0.09, 0.075, 0.05)
const HEAD := Color(0.06, 0.045, 0.035)
const PETAL := Color(0.2, 0.15, 0.07)
## Как быстро голова доворачивается за героем, рад/с.
const TURN := 0.9

var _heads: Array[Node3D] = []
var _lag: Array[float] = []
var _player: Node3D


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stem_mat := _material(STEM)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.035
	stem.bottom_radius = 0.05
	stem.height = 1.0
	stem.radial_segments = 5
	stem.rings = 1
	stem.material = stem_mat
	var head := CylinderMesh.new()
	head.top_radius = 0.24
	head.bottom_radius = 0.28
	head.height = 0.12
	head.radial_segments = 10
	head.rings = 1
	head.material = _material(HEAD)
	var petals := CylinderMesh.new()
	petals.top_radius = 0.4
	petals.bottom_radius = 0.42
	petals.height = 0.03
	petals.radial_segments = 12
	petals.rings = 1
	petals.material = _material(PETAL)
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.36, 0.03, 0.16)
	leaf.material = stem_mat
	var target := _focus_point()
	for i in count:
		var x := length * (i + rng.randf_range(0.2, 0.8)) / count
		var h := height * rng.randf_range(0.8, 1.15)
		var lean := rng.randf_range(-0.1, 0.1)
		var base := Vector3(x, rise * x / maxf(length, 0.01) - 0.1, rng.randf_range(-0.3, 0.3))
		var stalk := MeshInstance3D.new()
		stalk.mesh = stem
		stalk.transform = Transform3D(Basis(Vector3.FORWARD, lean).scaled(Vector3(1.0, h, 1.0)), base + Vector3(-sin(lean) * h * 0.5, h * 0.5, 0.0))
		add_child(stalk)
		for k in 2:
			var blade := MeshInstance3D.new()
			blade.mesh = leaf
			var side := -1.0 if k == 0 else 1.0
			blade.transform = Transform3D(Basis(Vector3.FORWARD, side * -0.6), base + Vector3(side * 0.15, h * (0.35 + k * 0.2), 0.0))
			add_child(blade)
		# Голова на шарнире у макушки стебля: ось диска — «взгляд» (−Z шарнира), сухая голова свисает вниз.
		var pivot := Node3D.new()
		pivot.position = base + Vector3(-sin(lean) * h, h, 0.0)
		add_child(pivot)
		var disc := Node3D.new()
		disc.rotation.x = PI * 0.5
		disc.position = Vector3(0.0, -0.08, -0.12)
		pivot.add_child(disc)
		for part: Mesh in [head, petals]:
			var piece := MeshInstance3D.new()
			piece.mesh = part
			disc.add_child(piece)
		_heads.append(pivot)
		_lag.append(rng.randf_range(0.0, 1.6))
		_aim(pivot, target, 1.0)
	set_process(_watching())


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	var target := _player.global_position + Vector3(0.0, 1.3, 0.0)
	for i in _heads.size():
		# Каждая голова трогается со своей задержкой — поле оборачивается вразнобой.
		_lag[i] -= delta
		if _lag[i] <= 0.0:
			_aim(_heads[i], target, TURN * delta)


func _watching() -> bool:
	return watch_flag != &"" and GameState.has_flag(watch_flag)


func _focus_point() -> Vector3:
	var node := get_node_or_null(focus) as Node3D
	return node.global_position if node else global_position + Vector3(-10.0, 2.0, 0.0)


## Довернуть голову к точке не больше чем на step радиан; голова всегда свешивается вниз.
func _aim(pivot: Node3D, target: Vector3, step: float) -> void:
	var from := pivot.global_position
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	if flat.length() < 0.01:
		return
	var wanted := Basis.looking_at(flat.normalized() + Vector3(0.0, -0.75, 0.0), Vector3.UP).get_rotation_quaternion()
	var current := pivot.global_basis.orthonormalized().get_rotation_quaternion()
	var angle := current.angle_to(wanted)
	var t := 1.0 if angle <= step or step >= 1.0 else step / angle
	pivot.global_basis = Basis(current.slerp(wanted, t))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
