extends Node3D
## Просмотр клипов Mixamo на манекене героя (§6.1, выбор клипов добиваний): клип крутится по кругу,
## в руке клинок, перед героем — манекен-жертва. Открыть в редакторе tools/characters/clip_viewer.tscn
## и запустить сцену (F6) или из консоли:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/characters/clip_viewer.tscn
## Клавиши: ↑↓ — роль, ←→ — вариант, Tab — роли / все клипы папки, Пробел — пауза,
## 1/2/3 — скорость ×1 / ×0.5 / ×0.25, C — камера (сбоку, как в игре / три четверти),
## T — жертва вкл/выкл, , и . — кадр назад/вперёд на паузе.
## Видео всех вариантов подряд (каждый — дважды, с подписью):
## "/c/Program Files/Godot/Godot.exe" --path . --write-movie D:/Downloads/mixamo/finishers.avi --fixed-fps 30 res://tools/characters/clip_viewer.tscn -- movie

const MIXAMO := "res://assets/characters/anims/mixamo"
const MODEL := "res://assets/characters/mannequin/ual1.glb"
const BLADE := 1.0
const GREAT_BLADE := 1.6
## Хват как у HeroModel.GRIP_* (как в anim_sheet.gd).
const GRIP_ROTATION := Vector3(0.0, 0.0, -PI * 0.5)
const GRIP_OFFSET := Vector3(0.0, 0.08, 0.02)
## Жертва стоит на дистанции удара перед героем.
const VICTIM_AT := 1.0
const SPEEDS := [1.0, 0.5, 0.25]
const MOVIE_LOOPS := 2

## Роли добиваний и варианты А/Б/В — как на листах finishers_choice_*.png; pick — мой совет.
## victim — клип играет жертва.
const ROLES := [
	{"title": "1. Меч: пронзить и выдернуть", "pick": 1, "clips": ["Stabbing lead hand (with skin)", "Stabbing (rear hand)", "ss slash"]},
	{"title": "2. Меч: удар в спину", "pick": 0, "clips": ["Standing Melee Attack Downward", "ss attack (4)", "ss slash (3)"]},
	{"title": "3. Добить лежачего", "pick": 0, "clips": ["Standing Melee Attack Downward", "ss slash (5)", "gs great sword slash (5)"]},
	{"title": "4. Молот: смертельный удар сверху", "pick": 2, "clips": ["gs great sword slash (4)", "gs great sword attack", "gs great sword jump attack"]},
	{"title": "5. Кол в сердце (вампир)", "pick": 0, "clips": ["Bayonet Stab", "Stabbing lead hand (with skin)", "Stabbing (rear hand)"]},
	{"title": "6. Жертва на клинке", "pick": 0, "victim": true, "clips": ["Big Stomach Hit", "Stomach Hit", "gs great sword impact (2)"]},
	{"title": "7. Жертва рушится", "pick": 0, "victim": true, "clips": ["Falling Back Death", "Dying Backwards", "Dying (two knees)"]},
	{"title": "8. Посох: заклинание", "pick": 0, "clips": ["Standing 1H Magic Attack 01 (one hand)", "Standing 2H Magic Attack 01"]},
]
const LETTERS := ["А", "Б", "В"]

var _hero: Node3D
var _hero_player: AnimationPlayer
var _victim: Node3D
var _victim_player: AnimationPlayer
var _blade_mesh: MeshInstance3D
var _blade: BoxMesh
var _camera: Camera3D
var _three_quarter := false
var _label: Label
var _help: Label
var _bar: ProgressBar
var _role := 0
var _variant := 0
var _all_mode := false
var _all_clips: Array[String] = []
var _all_index := 0
var _speed := 0
var _show_victim := true
var _loaded := {}
var _movie := false


func _ready() -> void:
	_movie = OS.get_cmdline_user_args().has("movie")
	_stage()
	_hero = _mannequin(Vector3.ZERO, PI * 0.5, Color(0.78, 0.78, 0.8))
	_hero_player = _hero.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_victim = _mannequin(Vector3(VICTIM_AT, 0.0, 0.0), -PI * 0.5, Color(0.45, 0.22, 0.2))
	_victim_player = _victim.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_hold_blade(_hero.find_child("GeneralSkeleton", true, false) as Skeleton3D)
	for file in DirAccess.get_files_at(MIXAMO):
		if file.ends_with(".fbx"):
			_all_clips.append(file.get_basename())
	_ui()
	_show()
	if _movie:
		_play_movie()


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.14, 0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	add_child(_camera)
	_place_camera()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 6.0)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.26, 0.28)
	plane.material = material
	add_child(ground)
	# Метки через полметра — видно, на сколько клип уводит героя.
	for i in range(-6, 7):
		var tick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.005, 0.6 if i % 2 == 0 else 0.3)
		tick.mesh = box
		tick.position = Vector3(i * 0.5, 0.003, 0.0)
		add_child(tick)


func _place_camera() -> void:
	var look := Vector3(VICTIM_AT * 0.5, 0.95, 0.0)
	_camera.position = look + (Vector3(-3.2, 0.9, 5.2) if _three_quarter else Vector3(0.0, 0.4, 6.2))
	_camera.look_at(look)


func _mannequin(at: Vector3, yaw: float, tint: Color) -> Node3D:
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	model.position = at
	model.rotation.y = yaw
	add_child(model)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.7
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material
	(model.find_child("AnimationPlayer", true, false) as AnimationPlayer).play(&"Idle")
	return model


## Клинок в правой кисти, как оружие героя.
func _hold_blade(skeleton: Skeleton3D) -> void:
	var hand := BoneAttachment3D.new()
	hand.bone_name = &"RightHand"
	skeleton.add_child(hand)
	var grip := Node3D.new()
	grip.rotation = GRIP_ROTATION
	grip.position = GRIP_OFFSET
	hand.add_child(grip)
	_blade = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.88, 0.92)
	material.metallic = 0.6
	_blade.material = material
	_blade_mesh = MeshInstance3D.new()
	_blade_mesh.mesh = _blade
	grip.add_child(_blade_mesh)


func _set_blade(length: float) -> void:
	_blade_mesh.visible = length > 0.0
	_blade.size = Vector3(0.05, maxf(length, 0.1), 0.015)
	_blade_mesh.position = Vector3(0.0, length * 0.5 - 0.08, 0.0)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	layer.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 26)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(420, 8)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	box.add_child(_bar)
	_help = Label.new()
	_help.add_theme_font_size_override(&"font_size", 15)
	_help.modulate = Color(1, 1, 1, 0.7)
	_help.text = "↑↓ роль   ←→ вариант   Tab все клипы   Пробел пауза   1/2/3 скорость   C камера   T жертва   , . кадр"
	_help.visible = not _movie
	box.add_child(_help)


## Клип из FBX (в библиотеку обоих манекенов под именем файла), шаг корня снят.
func _clip(stem: String) -> StringName:
	var key := StringName(stem)
	if _loaded.has(key):
		return key
	var scene := (load("%s/%s.fbx" % [MIXAMO, stem]) as PackedScene).instantiate()
	var from := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip := from.get_animation(from.get_animation_list()[-1]).duplicate() as Animation
	scene.free()
	_pin_root(clip)
	clip.loop_mode = Animation.LOOP_LINEAR
	for player in [_hero_player, _victim_player]:
		(player as AnimationPlayer).get_animation_library(&"").add_animation(key, clip)
	_loaded[key] = true
	return key


## Как в anim_sheet.gd: таз к концу клипа там же, где в начале.
static func _pin_root(clip: Animation) -> void:
	var track := clip.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
	if track < 0 or clip.track_get_key_count(track) < 2:
		return
	var count := clip.track_get_key_count(track)
	var first: Vector3 = clip.track_get_key_value(track, 0)
	var drift: Vector3 = clip.track_get_key_value(track, count - 1) - first
	var length := maxf(clip.length, 0.001)
	for k in count:
		var t := clip.track_get_key_time(track, k) / length
		var at: Vector3 = clip.track_get_key_value(track, k)
		clip.track_set_key_value(track, k, Vector3(at.x - drift.x * t, at.y, at.z - drift.z * t))


func _current() -> String:
	if _all_mode:
		return _all_clips[_all_index]
	return ROLES[_role]["clips"][_variant]


func _letter() -> String:
	return LETTERS[_variant]


func _is_victim_role() -> bool:
	return not _all_mode and ROLES[_role].get("victim", false)


func _show() -> void:
	var stem := _current()
	var anim := _clip(stem)
	var victim_role := _is_victim_role()
	# Роль жертвы: клип играет манекен-жертва, герой стоит с клинком.
	var actor := _victim_player if victim_role else _hero_player
	var other := _hero_player if victim_role else _victim_player
	_victim.visible = _show_victim or victim_role
	_set_blade(GREAT_BLADE if stem.begins_with("gs ") else BLADE)
	actor.play(anim, 0.0)
	actor.seek(0.0, true)
	other.play(&"Idle", 0.2)
	actor.speed_scale = SPEEDS[_speed]
	var length := actor.get_animation(anim).length
	if _all_mode:
		_label.text = "Все клипы %d/%d: %s\n%.2f с   скорость ×%s" % [
			_all_index + 1, _all_clips.size(), stem, length, str(SPEEDS[_speed])]
	else:
		var pick := "   ★ мой совет" if ROLES[_role]["pick"] == _variant else ""
		_label.text = "%s\nВариант %s: %s%s\n%.2f с   скорость ×%s" % [
			ROLES[_role]["title"], _letter(), stem, pick, length, str(SPEEDS[_speed])]


func _process(_delta: float) -> void:
	var actor := _victim_player if _is_victim_role() else _hero_player
	if actor.current_animation != &"" and actor.current_animation_length > 0.0:
		_bar.value = actor.current_animation_position / actor.current_animation_length


func _unhandled_input(event: InputEvent) -> void:
	if _movie or not (event is InputEventKey and event.pressed):
		return
	var actor := _victim_player if _is_victim_role() else _hero_player
	match (event as InputEventKey).keycode:
		KEY_UP, KEY_DOWN:
			var step := -1 if event.keycode == KEY_UP else 1
			if _all_mode:
				_all_index = wrapi(_all_index + step, 0, _all_clips.size())
			else:
				_role = wrapi(_role + step, 0, ROLES.size())
				_variant = 0
			_show()
		KEY_LEFT, KEY_RIGHT:
			var step := -1 if event.keycode == KEY_LEFT else 1
			if _all_mode:
				_all_index = wrapi(_all_index + step, 0, _all_clips.size())
			else:
				_variant = wrapi(_variant + step, 0, ROLES[_role]["clips"].size())
			_show()
		KEY_TAB:
			_all_mode = not _all_mode
			_show()
		KEY_SPACE:
			if actor.is_playing():
				actor.pause()
			else:
				actor.play()
		KEY_1, KEY_2, KEY_3:
			_speed = event.keycode - KEY_1
			_show()
		KEY_C:
			_three_quarter = not _three_quarter
			_place_camera()
		KEY_T:
			_show_victim = not _show_victim
			_victim.visible = _show_victim or _is_victim_role()
		KEY_COMMA, KEY_PERIOD:
			actor.pause()
			var frame := 1.0 / 30.0 * (-1.0 if event.keycode == KEY_COMMA else 1.0)
			actor.seek(clampf(actor.current_animation_position + frame, 0.0, actor.current_animation_length), true)


## Для видео: все роли и варианты подряд, каждый клип MOVIE_LOOPS раз, потом выход.
func _play_movie() -> void:
	await get_tree().process_frame
	for r in ROLES.size():
		for v in (ROLES[r]["clips"] as Array).size():
			_role = r
			_variant = v
			_show()
			var actor := _victim_player if _is_victim_role() else _hero_player
			await get_tree().create_timer(actor.current_animation_length * MOVIE_LOOPS + 0.4).timeout
	get_tree().quit()
