extends Node
## Снимки героя на лестнице (§3.3): поза рук и ног на перекладинах по ходу подъёма.
## Нужен рендер — запускать без --headless (в облаке — через xvfb-run). Картинки — в user://ladder_snapshots/.
## Комната — первым аргументом после «--» (по умолчанию стена леса), берётся первая лестница в ней.

const OUT := "user://ladder_snapshots"
const ROOM := &"forest_wall"

var _main: Node
var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	_main = load("res://main.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	_main.get_node("RoomManager").start_room = StringName(args[0]) if args.size() > 0 else ROOM
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.0).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	for foe in get_tree().get_nodes_in_group("enemy"):
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	var ladder: Ladder
	for node in rooms.current_room.find_children("*", "Ladder", true, false):
		ladder = node
		break
	# Программный рендер (режим совместимости) не знает прозрачности узла: капсула и клинок-призрак
	# видны поверх манекена. На снимках их убираем со всех слоёв.
	for node in _player.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).transparency >= 0.99:
			(node as GeometryInstance3D).layers = 0
	_player.teleport(ladder.global_position + Vector3(0.0, 0.1, 0.0))
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(0.5).timeout
	await _shot("0_room", false)
	# Вверх: кадры через 0.05 с — виден перехват; потом стоит; потом съезжает вниз.
	Input.action_press("move_up")
	await get_tree().create_timer(0.3).timeout
	for i in 6:
		await _shot("up_%d" % i, true)
		await get_tree().create_timer(0.05).timeout
	Input.action_release("move_up")
	await get_tree().create_timer(0.4).timeout
	await _shot("still", true)
	Input.action_press("move_down")
	for i in 3:
		await get_tree().create_timer(0.12).timeout
		await _shot("down_%d" % i, true)
	Input.action_release("move_down")
	get_tree().quit()


func _shot(shot_name: String, crop: bool) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if crop:
		var cam := get_viewport().get_camera_3d()
		# Окно растянуто от базового разрешения проекта: точку героя переводим в пиксели снимка.
		var at := cam.unproject_position(_player.global_position + Vector3(0.0, 0.9, 0.0)) \
			* (Vector2(img.get_size()) / get_viewport().get_visible_rect().size)
		var rect := Rect2i(int(at.x) - 160, int(at.y) - 170, 320, 340).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(rect)
		img.resize(rect.size.x * 2, rect.size.y * 2, Image.INTERPOLATE_LANCZOS)
	img.save_png("%s/%s.png" % [OUT, shot_name])
