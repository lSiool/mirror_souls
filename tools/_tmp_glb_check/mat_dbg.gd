extends SceneTree
func _init() -> void:
	var s := (load("res://assets/characters/werewolf_young/werewolf_young.glb") as PackedScene).instantiate()
	for m in s.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			print(mi.name, " surf", i, " transparency=", mat.transparency, " alpha=", mat.albedo_color.a, " tex=", mat.albedo_texture != null, " cull=", mat.cull_mode, " depth_draw=", mat.depth_draw_mode)
	s.free(); quit()
