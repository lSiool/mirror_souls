extends SceneTree
func _init() -> void:
	await process_frame
	var enemy := (load("res://actors/enemies/werewolf.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(enemy)
	await process_frame
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var model = enemy.get(&"model")
	var sk: Skeleton3D = model.hero.skeleton
	model.hero.process_mode = Node.PROCESS_MODE_ALWAYS
	var anim: AnimationPlayer = model.hero.anim
	var room := sk.find_child("ArmRoom", true, false) as ArmRoom
	print("skeleton xform ", sk.global_transform)
	for on in [false, true]:
		room.active = on
		anim.play(&"Idle", 0.0); anim.seek(0.3, true); anim.speed_scale = 0.0
		for i in 4: await process_frame
		var out := {}
		for b in ["Hips","Neck","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightHand"]:
			out[b] = sk.get_bone_global_pose(sk.find_bone(b)).origin.snapped(Vector3.ONE*0.01)
		print("room=", on, " turn=", room.last_turn, " ", out)
	quit()
