extends Node3D
## Витрина персонажей (2026-11-16, docs/CHARACTER_PIPELINE.md): один персонаж под ровным светом, клипы — клавишами.
## Для проверки модели, рига и анимаций без игры: враг стоит (ИИ выключен), клип выбирается вручную.
##
## Запуск (нужен рендер, без --headless):
##   "/c/Program Files/Godot/Godot.exe" --path . res://tools/characters/character_gallery.tscn
##   … -- char=werewolf clip=Melee_Hook yaw=90   (yaw — от вида спереди, градусы; noroom — без ArmRoom)
## Снимки для проверки без окна (кадр на 40 % клипа, потом выход), в user://gallery/:
##   … -- char=werewolf clips=Idle,Jog_Fwd,Melee_Hook shots
## Несколько кадров клипа (доли длины): … -- char=werewolf clips=Melee_Hook at=0.2,0.5,0.8 shots
##
## Клавиши: ←/→ — персонаж, ↑/↓ — клип, Пробел — пауза, R — клип сначала, Q/E — повернуть камеру на 45°,
## 1 — спереди, 3 — сбоку, колесо или +/− — ближе/дальше, F — кадр по персонажу.
## Крупно одну кость: … -- char=werewolf bone=LeftForeArm dist=1.0
## Дыры в сетке: … -- char=werewolf bg=1,0,1 (без пола, фон насквозь)
## Клипы — общие клипы манекена (Quaternius UAL) и, если лежат в assets/characters/anims/mixamo (не в git),
## клипы Mixamo под именами «Mx_<файл>» (шаг корня снят, как в tools/characters/anim_sheet.gd).

const MIXAMO := "res://assets/characters/anims/mixamo"
const SHOTS := "user://gallery"
## Персонажи: имя на экране, id, сцена (пусто — модель героя).
const CHARACTERS := [
	["Герой", &"hero", ""],
	["Недавно обращённый оборотень", &"werewolf", "res://actors/enemies/werewolf.tscn"],
	["Вампир", &"vampire", "res://actors/enemies/vampire.tscn"],
	["Безмолвный Кузнец", &"blacksmith", "res://actors/enemies/blacksmith.tscn"],
	["Утопленник", &"drowned", "res://actors/enemies/drowned_knight.tscn"],
	["Солдат", &"soldier", "res://actors/enemies/dummy.tscn"],
	["Разбойник (примитивы)", &"bandit", "res://actors/enemies/bandit_heavy.tscn"],
	["Крыса (примитивы)", &"rat", "res://actors/enemies/rat.tscn"],
	["Летучая мышь (примитивы)", &"bat", "res://actors/enemies/bat.tscn"],
	["Стеклянный ползун (примитивы)", &"crawler", "res://actors/enemies/glass_crawler.tscn"],
]

var _index := 0
var _actor: Node3D
var _anim: AnimationPlayer
var _clips: PackedStringArray = []
var _clip := 0
var _yaw := 30.0
## Куда смотрит персонаж (градусы камеры «спереди»): враги в комнатах повёрнуты боком.
var _front := 0.0
var _pitch := 8.0
var _dist := 4.0
var _focus := Vector3(0.0, 1.0, 0.0)
var _camera: Camera3D
var _label: Label
var _args := {}


func _ready() -> void:
	GameState.saves_enabled = false
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_build_stage()
	var want := StringName(_args.get("char", "werewolf"))
	for i in CHARACTERS.size():
		if CHARACTERS[i][1] == want:
			_index = i
	await _show(_index)
	if _args.has("clip"):
		_select_clip(_args["clip"])
	if _args.has("shots"):
		await _take_shots()
		get_tree().quit()


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.28, 0.29, 0.31)
	if _args.has("bg"):
		# Яркий фон (bg=1,0,1) — дыры и щели в сетке видны насквозь.
		var c: PackedStringArray = _args["bg"].split(",")
		env.environment.background_color = Color(float(c[0]), float(c[1]), float(c[2]))
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	# Ключевой свет сверху-спереди, заполняющий сбоку, контровой сзади — модель читается целиком.
	for light: Array in [[Vector3(-40, 30, 0), 1.3], [Vector3(-15, -70, 0), 0.45], [Vector3(-25, 160, 0), 0.8]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = light[0]
		sun.light_energy = light[1]
		sun.shadow_enabled = light[1] > 1.0
		add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.visible = not _args.has("bg")
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.21)
	plane.material = mat
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	_camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_label)


## Показать персонажа: враг — его сцена с выключенным ИИ, герой — модель героя.
func _show(i: int) -> void:
	if is_instance_valid(_actor):
		_actor.queue_free()
		await get_tree().process_frame
	_index = wrapi(i, 0, CHARACTERS.size())
	var path: String = CHARACTERS[_index][2]
	if path == "":
		_actor = HeroModel.new()
		add_child(_actor)
		_anim = (_actor as HeroModel).anim
	else:
		_actor = (load(path) as PackedScene).instantiate() as Node3D
		add_child(_actor)
		await get_tree().process_frame
		_actor.process_mode = Node.PROCESS_MODE_DISABLED
		var model: EnemyModel = _actor.get(&"model")
		_anim = model.hero.anim if model else null
	_clips = PackedStringArray()
	if _anim:
		_anim.process_mode = Node.PROCESS_MODE_ALWAYS
		# Скелет тоже: модификаторы поверх клипа (ArmRoom, GripHands) идут в его обработке.
		for skeleton in _actor.find_children("*", "Skeleton3D", true, false):
			skeleton.process_mode = Node.PROCESS_MODE_ALWAYS
		_load_mixamo(_anim.get_animation_library(&""))
		for name in _anim.get_animation_list():
			if not String(name).contains("@"):  # позы-стоп-кадры HeroModel.hold
				_clips.append(name)
		_clips.sort()
		_clip = maxi(_clips.find("Idle"), 0)
		_play()
	await get_tree().process_frame
	var forward := (_actor.get(&"model").hero if _actor.get(&"model") else _actor).global_basis.z as Vector3
	_front = rad_to_deg(atan2(forward.x, forward.z))
	_yaw = _front + float(_args.get("yaw", "30"))
	var room := _actor.find_child("ArmRoom", true, false) as SkeletonModifier3D
	if room and _args.has("noroom"):
		room.active = false
	_frame()
	_update_label()


func _play(blend := 0.15) -> void:
	if _anim and not _clips.is_empty():
		_anim.play(_clips[_clip], blend)
		_anim.speed_scale = 1.0


func _select_clip(name: String, blend := 0.15) -> void:
	var at := _clips.find(name)
	if at < 0:
		at = _clips.find("Mx_" + name.replace(" ", "_"))
	if at >= 0:
		_clip = at
		_play(blend)
		_update_label()


## Кадр по персонажу: по костям скелета (следуют за клипом), без скелета — по видимым мешам.
## bone=<кость> (аргумент) — крупный план этой кости, dist=<м> — расстояние.
func _frame() -> void:
	var box := AABB()
	var first := true
	var skeleton: Skeleton3D = null
	for node in _actor.find_children("*", "Skeleton3D", true, false):
		if (node as Skeleton3D).is_visible_in_tree() and (node as Skeleton3D).get_bone_count() > 10:
			skeleton = node
	if skeleton:
		var close := skeleton.find_bone(_args.get("bone", ""))
		if close >= 0:
			_focus = skeleton.global_transform * skeleton.get_bone_global_pose(close).origin
			_dist = float(_args.get("dist", "1.2"))
			_place_camera()
			return
		for i in skeleton.get_bone_count():
			var at := skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
			box = AABB(at, Vector3.ZERO) if first else box.expand(at)
			first = false
		box = box.grow(0.25)
		_focus = box.get_center()
		_dist = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.6 + 0.6
		_place_camera()
		return
	for node in _actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	_focus = box.get_center()
	_dist = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.6 + 0.6
	_place_camera()


func _place_camera() -> void:
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_camera.look_at_from_position(_focus + dir * _dist, _focus)


func _update_label() -> void:
	var clip := _clips[_clip] if not _clips.is_empty() else "— (нет клипов: примитивы)"
	var paused := " [пауза]" if _anim and _anim.speed_scale == 0.0 else ""
	_label.text = "%s (%s)    клип %d/%d: %s%s\n←/→ персонаж   ↑/↓ клип   Пробел пауза   R сначала   Q/E поворот   1 спереди   3 сбоку   колесо — ближе/дальше   F кадр" % [
		CHARACTERS[_index][0], CHARACTERS[_index][1], _clip + 1, _clips.size(), clip, paused]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 0.8)
			_place_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist *= 1.1
			_place_camera()
		return
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_RIGHT: _show(_index + 1)
		KEY_LEFT: _show(_index - 1)
		KEY_DOWN, KEY_UP:
			if not _clips.is_empty():
				_clip = wrapi(_clip + (1 if event.keycode == KEY_DOWN else -1), 0, _clips.size())
				_play()
		KEY_SPACE:
			if _anim:
				_anim.speed_scale = 0.0 if _anim.speed_scale > 0.0 else 1.0
		KEY_R: _play()
		KEY_Q: _yaw -= 45.0; _place_camera()
		KEY_E: _yaw += 45.0; _place_camera()
		KEY_1: _yaw = _front; _place_camera()
		KEY_3: _yaw = _front + 90.0; _place_camera()
		KEY_EQUAL, KEY_KP_ADD: _dist = maxf(_dist * 0.9, 0.8); _place_camera()
		KEY_MINUS, KEY_KP_SUBTRACT: _dist *= 1.1; _place_camera()
		KEY_F: _frame()
	_update_label()


## Снимки: каждый клип из clips= (или текущий) — кадры на долях длины из at= (по умолчанию 0.4).
func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var wanted: PackedStringArray = _args.get("clips", "").split(",", false)
	if wanted.is_empty() and not _clips.is_empty():
		wanted = [_clips[_clip]]
	if wanted.is_empty():
		wanted = ["none"]
	var times: PackedStringArray = _args.get("at", "0.4").split(",", false)
	for name in wanted:
		for at in times:
			if _anim and name != "none":
				_select_clip(name, 0.0)  # без перехода: на паузе он не идёт
				_anim.seek(_anim.get_animation(_clips[_clip]).length * float(at), true)
				_anim.speed_scale = 0.0
			for f in 6:
				await get_tree().process_frame
			_frame()  # клип с шагом корня уводит персонажа из кадра
			await get_tree().process_frame
			var suffix := "" if times.size() == 1 else "_%02d" % roundi(float(at) * 100.0)
			var file := "%s/%s_%s%s.png" % [SHOTS, CHARACTERS[_index][1], name.replace(" ", "_"), suffix]
			get_viewport().get_texture().get_image().save_png(file)
			var room := _actor.find_child("ArmRoom", true, false)
			print("SHOT ", ProjectSettings.globalize_path(file), "  arm_room=", room.last_turn if room else "-")


## Клипы Mixamo из папки (если есть) — в библиотеку манекена, шаг корня снят.
func _load_mixamo(lib: AnimationLibrary) -> void:
	if not DirAccess.dir_exists_absolute(MIXAMO):
		return
	for file in DirAccess.get_files_at(MIXAMO):
		if not file.ends_with(".fbx"):
			continue
		var name := StringName("Mx_" + file.get_basename().replace(" ", "_").replace("(", "").replace(")", "").replace(",", ""))
		if lib.has_animation(name):
			continue
		var scene := (load(MIXAMO + "/" + file) as PackedScene).instantiate()
		var from := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if from and not from.get_animation_list().is_empty():
			var clip := from.get_animation(from.get_animation_list()[-1]).duplicate(true) as Animation
			_pin_root(clip)
			lib.add_animation(name, clip)
		scene.free()


static func _pin_root(clip: Animation) -> void:
	var track := clip.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
	if track < 0 or clip.track_get_key_count(track) < 2:
		return
	var count := clip.track_get_key_count(track)
	var first: Vector3 = clip.track_get_key_value(track, 0)
	var drift: Vector3 = clip.track_get_key_value(track, count - 1) - first
	for k in count:
		var t := clip.track_get_key_time(track, k) / maxf(clip.length, 0.001)
		var at: Vector3 = clip.track_get_key_value(track, k)
		clip.track_set_key_value(track, k, Vector3(at.x - drift.x * t, at.y, at.z - drift.z * t))
