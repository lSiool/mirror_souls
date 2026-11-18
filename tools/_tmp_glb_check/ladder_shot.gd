extends Node
## Временный: снимки подъёма по лестнице (клип Mixamo). Удалить после проверки.

func _ready() -> void:
	GameState.saves_enabled = false
	var main: Node = load("res://main.tscn").instantiate()
	main.get_node("RoomManager").start_room = &"village_house"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(2.5).timeout
	var rooms := main.get_node("RoomManager") as RoomManager
	var player := main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	for foe in get_tree().get_nodes_in_group("enemy"):
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	player.teleport(Vector3(7.5, 0.1, 0.0))
	rooms.camera_rig.zoom(0.7, 0.0)
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_up")
	for i in 6:
		await get_tree().create_timer(0.22).timeout
		get_viewport().get_texture().get_image().save_png("user://ladder_%d.png" % i)
		print("SHOT %d y=%.2f state=%d" % [i, player.global_position.y, player.state])
	Input.action_release("move_up")
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("user://ladder_6.png")
	get_tree().quit()
