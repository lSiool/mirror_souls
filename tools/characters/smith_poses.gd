extends Node3D
## Лист поз Кузнеца (§6.3): стоит, идёт, замахи, удар, волок — сбоку, в три четверти и крупно кисти
## на рукояти (третий ряд, спереди-сбоку), на ровном сером фоне, чтобы видно было руки и ноги. Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/characters/smith_poses.tscn
## Картинка — user://smith_poses/sheet.png.

const OUT := "user://smith_poses"
const CELL := Vector2i(360, 420)
## Поза: имя, состояние, угол молота, наклон плоскости удара (крест), скорость, время атаки
## (больше 0.5 — волок).
const POSES := [
	["stand", Dummy.State.CHASE, Blacksmith.POSE_DRAG, 0.0, 0.0, 0.18],
	["walk", Dummy.State.CHASE, Blacksmith.POSE_DRAG, 0.0, 1.4, 0.18],
	["sweep_windup", Dummy.State.WINDUP, Blacksmith.POSE_BACK, 0.0, 0.0, 0.18],
	["shoulder", Dummy.State.WINDUP, Blacksmith.POSE_SHOULDER, Blacksmith.SLAM_TILT, 0.0, 0.18],
	["x1_top", Dummy.State.WINDUP, Blacksmith.POSE_OVERHEAD, Blacksmith.SLAM_TILT, 0.0, 0.18],
	["x1_floor", Dummy.State.RECOVER, Blacksmith.POSE_FLOOR, Blacksmith.SLAM_TILT, 0.0, 0.18],
	["x2_top", Dummy.State.WINDUP, Blacksmith.POSE_OVERHEAD, -Blacksmith.SLAM_TILT, 0.0, 0.18],
	["x2_floor", Dummy.State.RECOVER, Blacksmith.POSE_FLOOR, -Blacksmith.SLAM_TILT, 0.0, 0.18],
	["swept", Dummy.State.ATTACK, Blacksmith.POSE_SWEPT, 0.0, 0.0, 0.18],
	["drag_run", Dummy.State.ATTACK, Blacksmith.POSE_DRAG, 0.0, 8.0, 0.75],
]

var _smith: Blacksmith
var _side: Camera3D
var _three_quarter: Camera3D
var _hands: Camera3D
var _pose: Array = []


func _ready() -> void:
	GameState.saves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.56, 0.58)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.62)
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 10.0)
	shape.shape = box
	ground.add_child(shape)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = box.size
	plate.mesh = plate_mesh
	ground.add_child(plate)
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_child(ground)
	_smith = (load("res://actors/enemies/blacksmith.tscn") as PackedScene).instantiate() as Blacksmith
	_smith.facing = 1.0
	add_child(_smith)
	_side = _camera(Vector3(0.0, 2.3, 9.0), Vector3.ZERO)
	_three_quarter = _camera(Vector3(6.0, 2.3, 6.5), Vector3(0.0, deg_to_rad(42.0), 0.0))
	_hands = _camera(Vector3.ZERO, Vector3(-0.25, deg_to_rad(30.0), 0.0))
	_hands.size = 1.3
	# Встал на пол — дальше физику ведёт лист (is_on_floor остаётся от последнего шага).
	for i in 30:
		await get_tree().physics_frame
	var sheet := Image.create(CELL.x * POSES.size(), CELL.y * 3, false, Image.FORMAT_RGBA8)
	for i in POSES.size():
		_pose = POSES[i]
		_smith.set_physics_process(false)
		for frame in 50:
			await get_tree().physics_frame
		var palms := (_smith.model.palm_point(0) + _smith.model.palm_point(1)) * 0.5
		_hands.position = palms + _hands.basis.z * 6.0
		for row in 3:
			([_side, _three_quarter, _hands][row] as Camera3D).current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var shot := get_viewport().get_texture().get_image()
			var width := shot.get_height() * CELL.x / CELL.y
			var crop := shot.get_region(Rect2i((shot.get_width() - width) / 2, 0, width, shot.get_height()))
			crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			crop.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, CELL.y * row))
		# Левая ладонь на древке: расстояние от её середины до оси рукояти.
		var right := _smith.model.palm_point(0)
		var axis := _smith.hammer.global_basis.y.normalized()
		var left := _smith.model.palm_point(1) - right
		print("pose %s: левая ладонь от древка %.3f м" % [_pose[0], (left - axis * left.dot(axis)).length()])
	sheet.save_png("%s/sheet.png" % OUT)
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if _pose.is_empty():
		return
	_smith.state = _pose[1]
	_smith.velocity = Vector3(_pose[4], 0.0, 0.0)
	_smith.attack_time = _pose[5]
	_smith.hammer.rotation.z = _pose[2]
	_smith.hammer.rotation.x = _pose[3]
	_smith.model.update(delta)


func _camera(at: Vector3, turn: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.4
	camera.position = at
	camera.rotation = turn
	add_child(camera)
	return camera
