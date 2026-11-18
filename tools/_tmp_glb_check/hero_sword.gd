extends Node
## Временный: герой с мечом на месте — снимки руки с моделью оружия. Удалить после проверки.

func _ready() -> void:
	GameState.saves_enabled = false
	var main: Node = load("res://main.tscn").instantiate()
	main.get_node("RoomManager").start_room = &"chapel_yard"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(2.5).timeout
	var rooms := main.get_node("RoomManager") as RoomManager
	var player := main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	player.teleport(Vector3(8.0, 0.1, 0.0))
	player.equip(&"sword")
	await get_tree().create_timer(0.3).timeout
	print("WEAPON ", player.weapon.id if player.weapon else "none", " armed=", player.arms.armed)
	var hand: Node3D = player.arms.hand
	print("HAND ", hand, " visible=", hand.visible if hand else false)
	if hand:
		for c in hand.get_children():
			print("  child ", c.name, " vis=", c.visible, " ", c.get_class())
			if c.name == &"Model":
				for m in c.find_children("*", "MeshInstance3D", true, false):
					print("   mesh aabb ", (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb(), " transp=", (m as MeshInstance3D).transparency)
	print("PLAYER at ", player.global_position)
	rooms.camera_rig.zoom(0.8, 0.0)
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png("user://hero_sword_0.png")
	Input.action_press("attack")
	await get_tree().create_timer(0.12).timeout
	Input.action_release("attack")
	await get_tree().create_timer(0.15).timeout
	get_viewport().get_texture().get_image().save_png("user://hero_sword_1.png")
	get_tree().quit()
