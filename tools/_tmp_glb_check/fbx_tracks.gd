extends SceneTree
func _init() -> void:
	for f in ["Climbing Ladder.fbx", "mutant swiping.fbx", "mutant walking.fbx"]:
		var s := (load("res://assets/characters/anims/mixamo/" + f) as PackedScene).instantiate()
		var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var names := ap.get_animation_list()
		var a := ap.get_animation(names[-1])
		var paths := []
		for t in mini(a.get_track_count(), 4):
			paths.append(str(a.track_get_path(t)))
		var sk := s.find_child("*", true, false)
		print(f, " anims=", names, " len=", a.length, " tracks=", a.get_track_count(), " ", paths)
		var skel := s.find_children("*", "Skeleton3D", true, false)
		print("   skeletons: ", skel.map(func(n): return str(n.name) + " unique=" + str(n.is_unique_name_in_owner()) + " bones=" + str(n.get_bone_count())))
		s.free()
	quit()
