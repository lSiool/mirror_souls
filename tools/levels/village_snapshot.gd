extends Node
## Общие планы горящей деревни (§9.2): крыши в огне, фон, очаги. Нужен рендер — запускать без --headless:
##   godot --path . res://tools/levels/village_snapshot.tscn -- room=village_street at=-26,1.3 at=-6,0.1 zoom=2.2
## at=x,y — место героя (по кадру на каждое), zoom — отдаление камеры. Картинки — в user://village_snapshots/.

const OUT := "user://village_snapshots"


func _ready() -> void:
	var room := &"village_street"
	var spots: Array[Vector2] = []
	var zoom := 2.2
	GameState.saves_enabled = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("room="):
			room = StringName(arg.trim_prefix("room="))
		elif arg.begins_with("at="):
			var xy := arg.trim_prefix("at=").split(",")
			spots.append(Vector2(float(xy[0]), float(xy[1])))
		elif arg.begins_with("zoom="):
			zoom = float(arg.trim_prefix("zoom="))
	var main: Node = load("res://main.tscn").instantiate()
	main.get_node("RoomManager").start_room = room
	get_tree().root.add_child.call_deferred(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.5).timeout
	var rooms := main.get_node("RoomManager") as RoomManager
	var player := main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	for foe in get_tree().get_nodes_in_group("enemy"):
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	var run := RunLevel.of(rooms.current_room)
	if run:
		run.set_physics_process(false)
	rooms.camera_rig.zoom(zoom, 0.0)
	for i in spots.size():
		player.teleport(Vector3(spots[i].x, spots[i].y, 0.0))
		rooms.camera_rig.snap_to_target()
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [OUT, room, i])
	get_tree().quit()
