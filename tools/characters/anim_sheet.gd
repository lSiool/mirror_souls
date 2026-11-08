extends SceneTree
## Листы кадров анимаций манекена (§3.3): по строке на клип, кадры через равные доли длины.
## Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . -s res://tools/characters/anim_sheet.gd -- Roll Sword_Regular_A
## Без имён — все клипы обоих наборов. Картинки — в user://anim_sheets/.

const OUT := "user://anim_sheets"
const MODELS := ["res://assets/characters/mannequin/ual1.glb", "res://assets/characters/mannequin/ual2.glb"]
const FRAMES := 8
const CELL := Vector2i(200, 260)
const ROWS_PER_SHEET := 6

var _viewport: SubViewport
var _player: AnimationPlayer
var _label: Label


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_viewport = SubViewport.new()
	_viewport.size = CELL
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	_viewport.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.6
	cam.position = Vector3(0.0, 1.0, 6.0)
	_viewport.add_child(cam)
	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(6.0, 0.02, 1.0)
	floor_mesh.mesh = plane
	_viewport.add_child(floor_mesh)

	var model := (load(MODELS[0]) as PackedScene).instantiate() as Node3D
	# Как в игре: герой смотрит вправо (+X), камера сбоку.
	model.rotation.y = PI * 0.5
	_viewport.add_child(model)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var extra := (load(MODELS[1]) as PackedScene).instantiate()
	var extra_lib := (extra.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation_library(&"")
	var lib := _player.get_animation_library(&"")
	for anim_name in extra_lib.get_animation_list():
		if not lib.has_animation(anim_name):
			lib.add_animation(anim_name, extra_lib.get_animation(anim_name))
	extra.free()

	var wanted := OS.get_cmdline_user_args()
	var names: Array = wanted if not wanted.is_empty() else Array(_player.get_animation_list())
	var sheet_index := 0
	for start in range(0, names.size(), ROWS_PER_SHEET):
		var rows := names.slice(start, start + ROWS_PER_SHEET)
		var sheet := Image.create(CELL.x * FRAMES, CELL.y * rows.size(), false, Image.FORMAT_RGBA8)
		for r in rows.size():
			await _row(sheet, r, StringName(rows[r]))
		var path := "%s/sheet_%02d.png" % [OUT, sheet_index]
		sheet.save_png(path)
		print("sheet ", ProjectSettings.globalize_path(path), " : ", ", ".join(rows))
		sheet_index += 1
	quit()


func _row(sheet: Image, row: int, anim_name: StringName) -> void:
	if not _player.has_animation(anim_name):
		print("нет клипа ", anim_name)
		return
	var length := _player.get_animation(anim_name).length
	_player.play(anim_name)
	for f in FRAMES:
		_player.seek(length * f / float(FRAMES - 1) * 0.999, true)
		await process_frame
		await process_frame
		var img := _viewport.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(f * CELL.x, row * CELL.y))
	# Подпись строки — имя клипа и длина в первом кадре: тёмная полоска, чтобы было видно.
	sheet.fill_rect(Rect2i(0, row * CELL.y, CELL.x, 3), Color(0.9, 0.6, 0.2))
	print("  ", anim_name, " %.2f s" % length)
