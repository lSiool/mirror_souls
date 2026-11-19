class_name Ambush
extends Node3D
## Засада со спины (§8.14): враг прячется в укрытии — в стоячем гробу, в вагонетке, под грудой костей — и
## выходит, когда герой прошёл мимо и повернулся к укрытию спиной. Честно: когда герой подходит, укрытие
## один раз вздрагивает и скребётся (звук, дрожь) — кто оглядывается и не спешит, тот готов.
## Враг — обычный враг комнаты (enemy), пока ждёт — выключен и не виден; укрытие строит сама засада.
## После отдыха у осколка засада снова на месте (комната перезагружается). Узел стоит на полу у укрытия.

signal sprung

enum Cover { COFFIN, CART, BONES }

const WOOD := Color(0.2, 0.14, 0.1)
const RUST := Color(0.3, 0.17, 0.1)
const IRON := Color(0.1, 0.1, 0.11)
const BONE := Color(0.72, 0.68, 0.58)

@export var enemy: NodePath
@export var cover := Cover.COFFIN
## Ближе этого (по x) укрытие вздрагивает — подсказка.
@export var cue_distance := 5.0
## На сколько герой должен пройти за укрытие, чтобы враг вышел у него за спиной.
@export var pass_distance := 2.0

var sprung_already := false

var _enemy: Dummy
var _cover: Node3D
var _side := 0.0
var _cued := false
var _shake := 0.0


func _ready() -> void:
	_cover = Node3D.new()
	_cover.name = &"Cover"
	add_child(_cover)
	match cover:
		Cover.COFFIN:
			_build_coffin()
		Cover.CART:
			_build_cart()
		Cover.BONES:
			_build_bones()
	_enemy = get_node_or_null(enemy) as Dummy
	if _enemy:
		_hide_enemy.call_deferred()


func _physics_process(delta: float) -> void:
	if sprung_already:
		return
	if _shake > 0.0:
		_shake -= delta
		_cover.rotation.z = sin(_shake * 70.0) * 0.04 * minf(_shake * 3.0, 1.0)
		if _shake <= 0.0:
			_cover.rotation.z = 0.0
	var hero := get_tree().get_first_node_in_group(&"player") as Player
	if hero == null or hero.is_dead():
		return
	var dx := hero.global_position.x - global_position.x
	if absf(hero.global_position.y - global_position.y) > 2.5:
		return
	if not _cued and absf(dx) < cue_distance:
		_cued = true
		_side = signf(dx)
		_shake = 0.5
		Sfx.play(&"ambush_scratch", global_position + Vector3(0.0, 1.0, 0.0))
	# Прошёл мимо: был с одной стороны, ушёл на pass_distance за укрытие — враг выходит за спиной.
	if _cued and signf(dx) == -_side and absf(dx) >= pass_distance:
		spring()


## Выпустить врага: укрытие раскрывается, враг сразу бросается на героя.
func spring() -> void:
	if sprung_already:
		return
	sprung_already = true
	_open_cover()
	Sfx.play(&"prop_break_wood", global_position + Vector3(0.0, 1.0, 0.0))
	if _enemy and is_instance_valid(_enemy):
		_enemy.global_position = Vector3(global_position.x, global_position.y + 0.05, 0.0)
		_enemy.visible = true
		_enemy.process_mode = Node.PROCESS_MODE_INHERIT
		_enemy.on_revealed()
	sprung.emit()


func _hide_enemy() -> void:
	if not is_instance_valid(_enemy):
		return
	_enemy.visible = false
	_enemy.process_mode = Node.PROCESS_MODE_DISABLED


func _open_cover() -> void:
	var tween := create_tween().set_parallel()
	match cover:
		Cover.COFFIN:
			var lid := _cover.get_node(^"Lid") as Node3D
			tween.tween_property(lid, "position", lid.position + Vector3(0.0, -0.6, 1.4), 0.35)
			tween.tween_property(lid, "rotation:x", 1.45, 0.35)
		Cover.CART:
			tween.tween_property(_cover, "rotation:z", 1.2 * (-_side if _side != 0.0 else 1.0), 0.3)
			tween.tween_property(_cover, "position:x", 0.6 * (-_side if _side != 0.0 else 1.0), 0.3)
		Cover.BONES:
			for bone in _cover.get_children():
				var node := bone as Node3D
				var out := Vector3(node.position.x * 2.5, 0.0, node.position.z * 0.5 + 0.6)
				tween.tween_property(node, "position", node.position + out, 0.3)
				tween.tween_property(node, "rotation:z", node.rotation.z + 2.0, 0.3)


## Стоячий гроб у стены, крышка спереди; за крышкой темно.
func _build_coffin() -> void:
	var wood := _material(WOOD)
	_box(_cover, "Box", Vector3(0.0, 1.05, -0.75), Vector3(0.9, 2.1, 0.5), wood)
	_box(_cover, "Dark", Vector3(0.0, 1.05, -0.49), Vector3(0.7, 1.9, 0.02), _material(Color(0.01, 0.01, 0.01)))
	var lid := _box(_cover, "Lid", Vector3(0.05, 1.05, -0.45), Vector3(0.86, 2.06, 0.08), wood)
	lid.rotation.z = 0.02


## Вагонетка у рельсов — короб на колёсах.
func _build_cart() -> void:
	var rust := _material(RUST)
	var iron := _material(IRON)
	_box(_cover, "Box", Vector3(0.0, 0.75, -0.9), Vector3(1.7, 1.0, 1.2), rust)
	for dx: float in [-0.55, 0.55]:
		_box(_cover, "Wheel%d" % int(dx * 10.0), Vector3(dx, 0.2, -0.28), Vector3(0.4, 0.4, 0.08), iron)
	_box(_cover, "Rim", Vector3(0.0, 1.27, -0.9), Vector3(1.8, 0.08, 1.3), iron)


## Груда костей и черепов у стены.
func _build_bones() -> void:
	var bone := _material(BONE)
	var heaps := [Vector3(-0.5, 0.15, -0.6), Vector3(0.0, 0.25, -0.8), Vector3(0.45, 0.15, -0.5), Vector3(0.1, 0.5, -0.9),
		Vector3(-0.25, 0.4, -0.7), Vector3(0.3, 0.38, -0.85)]
	for i in heaps.size():
		var piece := _box(_cover, "Bone%d" % i, heaps[i], Vector3(0.6, 0.12, 0.14), bone)
		piece.rotation = Vector3(0.0, 0.4 * i, 0.3 * (i % 3 - 1))
	for i in 2:
		var skull := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.26
		sphere.material = bone
		skull.mesh = sphere
		skull.name = "Skull%d" % i
		skull.position = Vector3(-0.15 + i * 0.4, 0.62 - i * 0.2, -0.75)
		_cover.add_child(skull)


func _box(parent: Node3D, box_name: String, at: Vector3, box_size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	box.material = material
	mesh.mesh = box
	mesh.name = box_name
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
