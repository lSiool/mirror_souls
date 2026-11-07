class_name BackgroundScene
extends Node3D
## Силуэты на заднем плане деревни в огне (§9.2), герой их только видит. Заглушка до настоящих
## моделей: тёмные фигуры из коробок, поза и размер меняются твинами.
## FIGHT — бой человека и твари по кругу; TURNING — человек на глазах становится оборотнем;
## CRAWL — человек отползает, тварь прыгает на него. Две последние начинаются, когда герой рядом.

enum Kind { FIGHT, TURNING, CRAWL }

const SHADOW := Color(0.03, 0.02, 0.02)
const EYES := Color(1.0, 0.15, 0.05)

@export var kind := Kind.FIGHT
@export var trigger_range := 15.0

var _player: Node3D
var _started := false


func _ready() -> void:
	match kind:
		Kind.FIGHT: _start_fight()
		Kind.TURNING: _build_turning()
		Kind.CRAWL: _build_crawl()


func _process(_delta: float) -> void:
	if _started or kind == Kind.FIGHT:
		set_process(false)
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if absf(_player.global_position.x - global_position.x) < trigger_range:
		_started = true
		if kind == Kind.TURNING:
			_play_turning()
		else:
			_play_crawl()


func _box(parent: Node3D, part: String, size: Vector3, at: Vector3, color := SHADOW) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = part
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _human(at: Vector3) -> Node3D:
	var figure := Node3D.new()
	figure.position = at
	add_child(figure)
	_box(figure, "Torso", Vector3(0.5, 1.05, 0.3), Vector3(0.0, 1.05, 0.0))
	_box(figure, "Legs", Vector3(0.4, 0.6, 0.26), Vector3(0.0, 0.3, 0.0))
	_box(figure, "Head", Vector3(0.28, 0.3, 0.26), Vector3(0.0, 1.72, 0.0))
	return figure


func _beast(at: Vector3) -> Node3D:
	var figure := Node3D.new()
	figure.position = at
	add_child(figure)
	_box(figure, "Torso", Vector3(0.95, 1.3, 0.45), Vector3(0.0, 1.05, 0.0))
	_box(figure, "Hump", Vector3(0.7, 0.4, 0.4), Vector3(-0.15, 1.75, 0.0))
	_box(figure, "Head", Vector3(0.62, 0.34, 0.3), Vector3(0.45, 1.7, 0.0))
	_box(figure, "EarA", Vector3(0.1, 0.3, 0.1), Vector3(0.28, 2.0, 0.0))
	_box(figure, "EarB", Vector3(0.1, 0.3, 0.1), Vector3(0.5, 2.0, 0.0))
	_box(figure, "Arm", Vector3(0.2, 1.25, 0.2), Vector3(0.62, 0.95, 0.0))
	_box(figure, "Eye", Vector3(0.1, 0.06, 0.32), Vector3(0.6, 1.76, 0.0), EYES)
	return figure


# --- Бой на фоне ------------------------------------------------------------

func _start_fight() -> void:
	var human := _human(Vector3(-0.85, 0.0, 0.0))
	_box(human, "Stake", Vector3(0.1, 1.2, 0.1), Vector3(0.42, 1.2, 0.0))
	var beast := _beast(Vector3(0.85, 0.0, 0.0))
	beast.scale.x = -1.0
	var tween := create_tween().set_loops()
	tween.tween_interval(randf_range(0.3, 1.4))
	tween.tween_property(beast, "position:x", 0.15, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(human, "rotation:z", 0.35, 0.22)
	tween.tween_property(human, "position:x", -1.2, 0.18)
	tween.tween_property(beast, "position:x", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(human, "rotation:z", 0.0, 0.5)
	tween.parallel().tween_property(human, "position:x", -0.85, 0.5)


# --- Перевоплощение ---------------------------------------------------------

func _build_turning() -> void:
	var figure := _human(Vector3.ZERO)
	figure.name = "Turning"
	# Звериное спрятано и растёт из человека.
	for part: MeshInstance3D in [
		_box(figure, "Hump", Vector3(0.7, 0.4, 0.4), Vector3(-0.15, 1.55, 0.0)),
		_box(figure, "EarA", Vector3(0.1, 0.3, 0.1), Vector3(-0.05, 2.0, 0.0)),
		_box(figure, "EarB", Vector3(0.1, 0.3, 0.1), Vector3(0.15, 2.0, 0.0)),
		_box(figure, "Snout", Vector3(0.4, 0.16, 0.2), Vector3(0.3, 1.68, 0.0)),
		_box(figure, "Arm", Vector3(0.2, 1.25, 0.2), Vector3(0.42, 0.95, 0.0)),
		_box(figure, "Eye", Vector3(0.1, 0.06, 0.3), Vector3(0.1, 1.78, 0.0), EYES),
	]:
		part.scale = Vector3.ZERO


func _play_turning() -> void:
	var figure := get_node("Turning") as Node3D
	var shake := create_tween().set_loops(10)
	shake.tween_property(figure, "position:x", 0.05, 0.05)
	shake.tween_property(figure, "position:x", -0.05, 0.05)
	await shake.finished
	var grow := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	grow.tween_property(figure, "rotation:z", -0.35, 1.6)
	grow.tween_property(figure, "scale", Vector3(1.45, 1.25, 1.2), 1.8)
	for part in ["Hump", "EarA", "EarB", "Snout", "Arm", "Eye"]:
		grow.tween_property(figure.get_node(part), "scale", Vector3.ONE, 1.6).set_delay(randf_range(0.0, 0.5))
	await grow.finished
	# Выпрямился, рванул прочь.
	var away := create_tween()
	away.tween_property(figure, "rotation:z", 0.1, 0.25)
	away.tween_interval(0.5)
	away.tween_property(figure, "position", Vector3(8.0, 0.0, -3.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await away.finished
	queue_free()


# --- Ужас отползающего человека ---------------------------------------------

func _build_crawl() -> void:
	var human := _human(Vector3(0.0, 0.3, 0.0))
	human.name = "Crawler"
	human.rotation.z = PI * 0.5
	var beast := _beast(Vector3(5.0, 0.0, 0.0))
	beast.name = "Hunter"
	beast.scale.x = -1.0


func _play_crawl() -> void:
	var human := get_node("Crawler") as Node3D
	var beast := get_node("Hunter") as Node3D
	var crawl := create_tween()
	crawl.tween_property(human, "position:x", -2.0, 3.6)
	var stalk := create_tween()
	stalk.tween_property(beast, "position:x", 1.2, 2.8)
	await stalk.finished
	var leap := create_tween().set_parallel(true)
	leap.tween_property(beast, "position:x", human.position.x + 0.2, 0.4)
	leap.tween_property(beast, "position:y", 1.6, 0.2).set_ease(Tween.EASE_OUT)
	leap.chain().tween_property(beast, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await leap.finished
	crawl.kill()
	# Склонился над жертвой.
	beast.rotation.z = 0.45
	var maul := create_tween().set_loops()
	maul.tween_property(beast, "rotation:z", 0.7, 0.35)
	maul.tween_property(beast, "rotation:z", 0.4, 0.35)
