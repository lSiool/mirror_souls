extends SceneTree
## Закрутка костей рук вокруг своей оси (рад, от позы покоя): оборотень и манекен на одних клипах.
func twist(sk: Skeleton3D, bone: String) -> float:
	var i := sk.find_bone(bone)
	var rel := sk.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * sk.get_bone_pose_rotation(i)
	# поворот вокруг оси кости (+Y) — часть twist
	var t := Quaternion(0, rel.y, 0, rel.w).normalized()
	return snappedf(rad_to_deg(t.get_angle()) * signf(rel.y * rel.w), 1)

func _init() -> void:
	await process_frame
	var enemy := (load("res://actors/enemies/werewolf.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(enemy)
	var hero := HeroModel.new()
	root.add_child(hero)
	await process_frame
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var model = enemy.get(&"model")
	model.hero.process_mode = Node.PROCESS_MODE_ALWAYS
	for who in [["wolf", model.hero], ["hero", hero]]:
		var h: HeroModel = who[1]
		print(who[0], " rest LowerArm ", h.skeleton.get_bone_rest(h.skeleton.find_bone("RightLowerArm")).basis.get_rotation_quaternion(), " Hand ", h.skeleton.get_bone_rest(h.skeleton.find_bone("RightHand")).basis.get_rotation_quaternion())
		for clip in ["Idle", "Punch_Cross", "Jog_Fwd"]:
			for at in [0.25, 0.5]:
				h.anim.play(clip, 0.0); h.anim.seek(h.anim.get_animation(clip).length * at, true); h.anim.speed_scale = 0.0
				await process_frame
				var row := []
				for b in ["RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"]:
					row.append("%s=%s" % [b.replace("Right", "R").replace("Left", "L"), twist(h.skeleton, b)])
				print(who[0], " ", clip, " ", at, " ", " ".join(row))
	quit()
