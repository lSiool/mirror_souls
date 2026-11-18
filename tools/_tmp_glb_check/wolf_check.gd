extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var wolf := (load("res://actors/enemies/werewolf.tscn") as PackedScene).instantiate()
	get_root().add_child(wolf)
	for i in 10: await process_frame
	var m = wolf.model
	print("MODEL ", m != null)
	if m:
		var mi: Array = m.find_children("*", "MeshInstance3D", true, false)
		for x in mi:
			var n := x as MeshInstance3D
			if n.visible and n.is_visible_in_tree():
				var b := n.global_transform * n.get_aabb()
				print("  mesh ", n.name, " h=%.2f pos=%s size=%s" % [b.size.y, b.position, b.size])
		print("  clip ", m.hero.anim.current_animation, " state=", wolf.state)
	for n in wolf.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).is_visible_in_tree() and not (m and m.is_ancestor_of(n)):
			print("  visible primitive: ", wolf.get_path_to(n))
	quit()
