extends Node
## Снимки катакомб (§8.13): тьма, фонарь, свечи. Нужен рендер — запускать без --headless:
##   godot --path . res://tools/levels/crypts_snapshot.tscn -- room=catacombs at=-12,0.1 at=10,0.1 lantern=1 candles=1 zoom=1.6
## at=x,y — место героя (по кадру на каждое); lantern=1 — фонарь в руке; candles=1 — все свечи комнаты горят;
## shield=1 — у героя щит (видно, что с фонарём он за спиной). Картинки — в user://crypts_snapshots/.

const OUT := "user://crypts_snapshots"


func _ready() -> void:
	var room := &"catacombs"
	var spots: Array[Vector2] = []
	var zoom := 1.6
	var lantern := false
	var candles := false
	var shield := false
	GameState.saves_enabled = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("room="):
			room = StringName(arg.trim_prefix("room="))
		elif arg.begins_with("at="):
			var xy := arg.trim_prefix("at=").split(",")
			spots.append(Vector2(float(xy[0]), float(xy[1])))
		elif arg.begins_with("zoom="):
			zoom = float(arg.trim_prefix("zoom="))
		elif arg == "lantern=1":
			lantern = true
		elif arg == "candles=1":
			candles = true
		elif arg == "shield=1":
			shield = true
	if not shield:
		GameState.shield_slots = [&"", &""]
	var main: Node = load("res://main.tscn").instantiate()
	main.get_node("RoomManager").start_room = room
	get_tree().root.add_child.call_deferred(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.5).timeout
	var rooms := main.get_node("RoomManager") as RoomManager
	var player := main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	if lantern:
		GameState.add_item(Player.LANTERN_ITEM)
		player.show_lantern(true)
		await get_tree().create_timer(0.2).timeout
		rooms.hud.popup.queue.clear()
		rooms.hud.popup.dismiss()
	if candles:
		for node in rooms.current_room.find_children("*", "WallCandle", true, false):
			GameState.set_flag((node as WallCandle).flag)
			(node as WallCandle)._set_lit(true)
	rooms.camera_rig.zoom(zoom, 0.0)
	var tag := "%s%s" % ["_lantern" if lantern else "", "_candles" if candles else ""]
	for i in spots.size():
		player.teleport(Vector3(spots[i].x, spots[i].y, 0.0))
		rooms.camera_rig.snap_to_target()
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s%s_%d.png" % [OUT, room, tag, i])
	get_tree().quit()
