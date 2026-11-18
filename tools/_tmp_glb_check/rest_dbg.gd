extends SceneTree
func _init() -> void:
	for path in ["res://assets/characters/mannequin/ual1.glb", "res://assets/characters/werewolf_young/werewolf_young.glb"]:
		var s := (load(path) as PackedScene).instantiate()
		var sk := s.find_child("GeneralSkeleton", true, false) as Skeleton3D
		var out := []
		for pair in [["LeftUpperArm","LeftLowerArm"],["LeftLowerArm","LeftHand"],["RightUpperArm","RightLowerArm"],["LeftUpperLeg","LeftLowerLeg"],["Hips","Spine"]]:
			var a := sk.get_bone_global_rest(sk.find_bone(pair[0])).origin
			var b := sk.get_bone_global_rest(sk.find_bone(pair[1])).origin
			out.append("%s->%s %s" % [pair[0], pair[1], (b - a).normalized().snapped(Vector3.ONE*0.01)])
		print(path.get_file(), " ", out)
		s.free()
	quit()
