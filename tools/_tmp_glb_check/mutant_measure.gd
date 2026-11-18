extends SceneTree
## Клипы Mutant на оборотне: длина, момент дальнего выноса лапы вперёд, скорость шага по корню.
func _init() -> void:
	await process_frame
	var enemy := (load("res://actors/enemies/werewolf.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(enemy)
	await process_frame
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var h: HeroModel = enemy.get(&"model").hero
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	var sk := h.skeleton
	var lib := h.anim.get_animation_library(&"")
	var hips := sk.find_bone("Hips")
	for f in ["Running Crawl", "Sneaking Forward", "Dodging Back"]:
		var s := (load("res://assets/characters/anims/mixamo/%s.fbx" % f) as PackedScene).instantiate()
		var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clip := ap.get_animation(ap.get_animation_list()[-1]).duplicate(true) as Animation
		s.free()
		var tr := clip.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
		var drift := Vector3.ZERO
		if tr >= 0:
			drift = clip.track_get_key_value(tr, clip.track_get_key_count(tr) - 1) - clip.track_get_key_value(tr, 0)
		var name := StringName("T_" + f.replace(" ", "_"))
		lib.add_animation(name, clip)
		h.anim.play(name, 0.0)
		h.anim.speed_scale = 0.0
		var best := [-99.0, 0.0, ""]
		var n := 40
		for i in n + 1:
			var t := clip.length * i / n
			h.anim.seek(t, true)
			await process_frame
			var base := sk.get_bone_global_pose(hips).origin
			for side in ["LeftHand", "RightHand"]:
				var p := sk.get_bone_global_pose(sk.find_bone(side)).origin - base
				if p.z > best[0]:
					best = [p.z, t / clip.length, side]
		print("%-22s len=%.2f  reach=%.2f at %.2f (%s)  drift=%s speed=%.2f" % [f, clip.length, best[0], best[1], best[2], drift.snapped(Vector3.ONE * 0.01), Vector2(drift.x, drift.z).length() / clip.length])
	quit()
