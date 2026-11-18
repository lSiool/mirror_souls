extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	get_root().size = Vector2i(1500, 700)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.3, 0.3, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(1, 1, 1); env.environment.ambient_light_energy = 0.7
	get_root().add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 25, 0); get_root().add_child(sun)
	var wolf := (load("res://actors/enemies/werewolf.tscn") as PackedScene).instantiate()
	get_root().add_child(wolf)
	for i in 5: await process_frame
	wolf.process_mode = Node.PROCESS_MODE_DISABLED
	var m = wolf.model
	m.hero.anim.process_mode = Node.PROCESS_MODE_ALWAYS
	var cam := Camera3D.new(); get_root().add_child(cam); cam.current = true; cam.fov = 40
	cam.look_at_from_position(Vector3(-0.5, 1.2, 4.5), Vector3(-0.5, 1.0, -1.0))
	var clips := ["Idle", "Jog_Fwd", "Melee_Hook"]
	for i in clips.size():
		m.hero.anim.play(clips[i]); m.hero.anim.seek(m.hero.anim.get_animation(clips[i]).length * 0.4, true)
		for f in 4: await process_frame
		get_root().get_texture().get_image().save_png("user://wolf_%d.png" % i)
	quit()
