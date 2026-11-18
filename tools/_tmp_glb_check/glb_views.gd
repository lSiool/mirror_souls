extends SceneTree
# Временный: снимки .glb с нескольких сторон. Запуск (нужен рендер, без --headless):
#   godot --path . -s res://tools/_tmp_glb_check/render.gd -- glb=res://assets/props/well/prop_well.glb out=user://glb_views
# После проверки удалить вместе с папкой.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var glb: String = args.get("glb", "res://assets/props/well/prop_well.glb")
	var out: String = args.get("out", "user://glb_views")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var root := Node3D.new()
	get_root().add_child(root)
	get_root().size = Vector2i(900, 900)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.36, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)

	var model: Node3D = (load(glb) as PackedScene).instantiate()
	root.add_child(model)
	await process_frame
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var tris := 0
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	print("AABB position=", box.position, " size=", box.size, " triangles=", tris)

	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 35.0
	var c := box.get_center()
	var r := box.size.length() * 0.5
	var dist := r / tan(deg_to_rad(cam.fov * 0.5)) * 1.1
	# 0..270 — вокруг; side9 — как в игре: сбоку, сверху 9°
	var views := {"front": Vector2(0, 15), "right": Vector2(90, 15), "back": Vector2(180, 15), "left": Vector2(270, 15), "game_side9": Vector2(0, 9)}
	# angles=0,45,90 — свои ракурсы (вид сверху 9°, как в игре), например чтобы выбрать поворот модели
	if args.has("angles"):
		views = {}
		for a in String(args["angles"]).split(","):
			views["a%03d" % int(a)] = Vector2(float(a), 9)
	for name in views:
		var v: Vector2 = views[name]
		var dir := Vector3(sin(deg_to_rad(v.x)), 0, cos(deg_to_rad(v.x))) * cos(deg_to_rad(v.y)) + Vector3(0, sin(deg_to_rad(v.y)), 0)
		cam.look_at_from_position(c + dir * dist, c)
		for i in 4:
			await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png(out.path_join(name + ".png"))
	print("SAVED ", ProjectSettings.globalize_path(out))
	quit()
