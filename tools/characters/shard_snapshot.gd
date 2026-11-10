extends Node
## Снимки героя у осколка (§8.4): подошёл, коснулся — стоит смирно, ладонь на кристалле, без мигания.
## Нужен рендер — запускать без --headless (в облаке — через xvfb-run). Картинки — в user://shard_snapshots/.

const OUT := "user://shard_snapshots"

var _main: Node
var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.5).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	rooms.hud.popup.blocks_interact = false
	# Программный рендер не знает прозрачности узла: капсулу и клинок-призрак убираем со слоёв.
	for node in _player.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).transparency >= 0.99:
			(node as GeometryInstance3D).layers = 0
	for side: float in [1.0, -1.0]:
		# Отдых пересоздаёт комнату — осколок каждый раз новый.
		var shard := rooms.current_room.get_node("Objects/MirrorShard") as MirrorShard
		_player.teleport(shard.global_position + Vector3(-side * 0.7, 0.1, 0.0))
		_player.facing = side
		rooms.camera_rig.snap_to_target()
		await get_tree().create_timer(0.3).timeout
		Input.action_press("interact")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("interact")
		await get_tree().create_timer(1.6).timeout
		for i in 3:
			await _shot("touch_%s_%d" % ["right" if side > 0.0 else "left", i])
			await get_tree().create_timer(0.07).timeout
		rooms.level_menu.close()
		await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cam := get_viewport().get_camera_3d()
	var at := cam.unproject_position(_player.global_position + Vector3(0.0, 1.0, 0.0))
	var rect := Rect2i(int(at.x) - 200, int(at.y) - 160, 400, 300).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png("%s/%s.png" % [OUT, shot_name])
