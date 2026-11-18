extends SceneTree
func _init() -> void:
	for f in ["Running Crawl", "Sneaking Forward", "Dodging Back"]:
		var s := (load("res://assets/characters/anims/mixamo/%s.fbx" % f) as PackedScene).instantiate()
		var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clip := ap.get_animation(ap.get_animation_list()[-1])
		var tr := clip.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
		var row := []
		for i in 21:
			var t := clip.length * i / 20.0
			var p: Vector3 = clip.position_track_interpolate(tr, t)
			row.append("%.2f" % p.y)
		print(f, " hips_y: ", " ".join(row))
		s.free()
	quit()
