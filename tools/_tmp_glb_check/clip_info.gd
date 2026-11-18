extends SceneTree
func _initialize() -> void:
	var scene := (load("res://assets/characters/anims/mixamo/Climbing Ladder.fbx") as PackedScene).instantiate()
	var ap := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in ap.get_animation_list():
		var c := ap.get_animation(n)
		print("CLIP ", n, " len=", c.length, " tracks=", c.get_track_count(), " loop=", c.loop_mode)
		var t := c.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
		if t >= 0:
			var k := c.track_get_key_count(t)
			for i in [0, k / 4, k / 2, 3 * k / 4, k - 1]:
				print("  hips t=%.2f %s" % [c.track_get_key_time(t, i), c.track_get_key_value(t, i)])
		for tr in range(min(3, c.get_track_count())):
			print("  track ", c.track_get_path(tr))
	scene.free()
	quit()
