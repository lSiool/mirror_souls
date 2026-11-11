extends Node
## Снимки героя с луком (§6.2): прицел прямо, вверх и вниз, с натяжением.
## Нужен рендер — запускать без --headless (в облаке — через xvfb-run). Картинки — в user://bow_snapshots/.

const OUT := "user://bow_snapshots"

var _main: Node
var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	GameState.set_flag(&"has_bow")
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.5).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	# Программный рендер не знает прозрачности узла: капсулу и клинок-призрак убираем со слоёв.
	for node in _player.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).transparency >= 0.99:
			(node as GeometryInstance3D).layers = 0
	for foe in get_tree().get_nodes_in_group("enemy"):
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	_player.teleport(Vector3(-9.0, 0.1, 0.0))
	_player.facing = 1.0
	_player.aim_source = Player.Aim.BUTTONS
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(0.4).timeout
	for shot: String in ["flat", "up"]:
		if shot == "up":
			Input.action_press("move_up")
		Input.action_press("shoot")
		await get_tree().create_timer(0.15).timeout
		await _shot(shot + "_start")
		await get_tree().create_timer(0.9).timeout
		await _shot(shot + "_drawn")
		Input.action_release("shoot")
		Input.action_release("move_up")
		await get_tree().create_timer(0.7).timeout
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cam := get_viewport().get_camera_3d()
	var at := cam.unproject_position(_player.global_position + Vector3(0.0, 1.0, 0.0))
	var rect := Rect2i(int(at.x) - 330, int(at.y) - 170, 300, 260).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var part := img.get_region(rect)
	part.resize(rect.size.x * 2, rect.size.y * 2, Image.INTERPOLATE_LANCZOS)
	part.save_png("%s/%s.png" % [OUT, shot_name])
