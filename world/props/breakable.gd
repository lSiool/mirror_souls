class_name Breakable
extends StaticBody3D
## Разрушаемый предмет: бочка, ящик, корзина, кувшин, урна (GAME_DESIGN §8.13).
## Бьётся ударом героя — меч, молот, стрела, бросок, таран: Hurtbox на слое «breakable», как у стекла.
## Лут не в каждом. Пустой предмет мир помнит разбитым до отдыха или смерти (как врагов), предмет с лутом —
## навсегда, чтобы лут нельзя было собирать снова (память — та же, что у стекла: GameState.mark_glass).
## Модель — сцена .glb из конвейера ComfyUI → TRELLIS.2: в файле ~1 м, нормализуется по model_bottom/model_height.

enum Stuff { WOOD, CLAY, WICKER, BONE }

const DEBRIS_LIFETIME := 2.0
const COLORS := {
	Stuff.WOOD: Color(0.3, 0.2, 0.12),
	Stuff.CLAY: Color(0.46, 0.28, 0.17),
	Stuff.WICKER: Color(0.5, 0.39, 0.22),
	Stuff.BONE: Color(0.74, 0.69, 0.58),
}
const BREAK_SOUND := {Stuff.WOOD: &"prop_break_wood", Stuff.CLAY: &"prop_break_clay", Stuff.WICKER: &"prop_break_wood", Stuff.BONE: &"prop_break_clay"}

@export var model: PackedScene
## Низ и высота модели в её файле (числа — D:\AI\comfy_tools\glb_bounds.py).
@export var model_bottom := -0.5
@export var model_height := 1.0
## Высота предмета в мире, м.
@export var height := 1.0
## Поворот модели по вертикали (рад) — чтобы одинаковые предметы не стояли одинаково.
@export var model_turn := 0.0
## Коробка столкновения и попадания (ширина, высота, глубина), низ — в точке узла.
@export var size := Vector3(0.8, 1.0, 0.8)
## Преграждает путь (на нём можно стоять). false — только для удара и красоты.
@export var solid := true
@export var stuff := Stuff.WOOD
## Сколько ударов держит: горшок — 1, бочка и ящик — 2.
@export var hits := 1
@export var echoes := 0
@export var item: StringName
@export var item_count := 1
## Флаг «лут уже взят» для предмета (кроме отзвуков).
@export var item_flag: StringName

var _hits_left := 1
var _broken := false
var _model: Node3D
var _shape: CollisionShape3D
var _hurtbox: Hurtbox


func _ready() -> void:
	add_to_group(&"breakable")
	_hits_left = maxi(hits, 1)
	collision_layer = 1 if solid else 0
	collision_mask = 0
	var box := BoxShape3D.new()
	box.size = size
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position.y = size.y * 0.5
	add_child(_shape)
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 16
	_hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.shape = box
	hurt_shape.position.y = size.y * 0.5
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)
	_hurtbox.hurt.connect(_on_hurt)
	if model:
		_model = model.instantiate() as Node3D
		var k := height / model_height
		_model.scale = Vector3.ONE * k
		_model.position.y = -model_bottom * k
		_model.rotation.y = model_turn
		add_child(_model)


func has_loot() -> bool:
	return echoes > 0 or (item != &"" and not (item_flag != &"" and GameState.has_flag(item_flag)))


func is_broken() -> bool:
	return _broken


## Удар: держит — качнулся и посыпалась щепа; последний удар — разлетается.
func _on_hurt(_hitbox: Hitbox) -> void:
	if _broken:
		return
	_hits_left -= 1
	if _hits_left > 0:
		Sfx.play(&"prop_hit_wood", global_position)
		_spawn_debris(4, 0.5)
		if _model:
			var tween := create_tween()
			tween.tween_property(_model, "rotation:z", 0.12, 0.05)
			tween.tween_property(_model, "rotation:z", -0.07, 0.08)
			tween.tween_property(_model, "rotation:z", 0.0, 0.1)
		return
	shatter()


func shatter() -> void:
	if _broken:
		return
	var loot := has_loot()
	_broken = true
	_disable()
	Sfx.play(BREAK_SOUND[stuff], global_position)
	Events.camera_shake_requested.emit(0.12, 0.1)
	_spawn_debris(12, 1.0)
	_spawn_dust()
	if loot:
		_drop_loot()
	# Память комнаты: с лутом — навсегда, пустой — до отдыха (RoomManager._on_prop_broken).
	set_meta(&"forever", loot)
	Events.prop_broken.emit(self)


## Комната пересоздана, а предмет мир помнит разбитым: без звука и обломков.
func set_broken() -> void:
	_broken = true
	_disable()


func _disable() -> void:
	_shape.set_deferred("disabled", true)
	_hurtbox.set_deferred("monitorable", false)
	if _model:
		_model.visible = false


func _drop_loot() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if echoes > 0:
		EchoDrop.spawn(get_parent(), global_position + Vector3(0.0, size.y * 0.6, 0.0), echoes, player)
	if item != &"" and not (item_flag != &"" and GameState.has_flag(item_flag)):
		GameState.add_item(item, item_count)
		if item_flag != &"":
			GameState.set_flag(item_flag)
		Events.item_found.emit(item)


## Обломки цвета материала: доски у дерева длинные, черепки у глины плоские.
func _spawn_debris(count: int, force: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[stuff]
	material.roughness = 0.95
	var parent := get_parent()
	for i in count:
		var piece := Vector3(randf_range(0.05, 0.14), randf_range(0.05, 0.12), randf_range(0.03, 0.06))
		if stuff == Stuff.WOOD:
			piece.y = randf_range(0.18, 0.4)
		piece *= clampf(height, 0.6, 1.5) * (1.0 if force >= 1.0 else 0.6)
		var body := RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = piece
		box.material = material
		mesh.mesh = box
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = piece
		shape.shape = collider
		body.add_child(shape)
		parent.add_child(body)
		body.global_position = global_position + Vector3(randf_range(-0.4, 0.4) * size.x, randf_range(0.2, 0.9) * size.y, randf_range(-0.2, 0.2))
		body.linear_velocity = Vector3(randf_range(-3, 3), randf_range(1.5, 5), randf_range(-1, 1)) * force
		body.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var tween := body.create_tween()
		tween.tween_interval(DEBRIS_LIFETIME * randf_range(0.6, 1.0))
		tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3)
		tween.tween_callback(body.queue_free)


func _spawn_dust() -> void:
	var dust := CPUParticles3D.new()
	var speck := SphereMesh.new()
	speck.radius = 0.12
	speck.height = 0.24
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.32, 0.28, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	speck.material = material
	dust.mesh = speck
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 14
	dust.lifetime = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = size * 0.4
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.6
	dust.gravity = Vector3(0, -1.0, 0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	get_parent().add_child(dust)
	dust.global_position = global_position + Vector3(0.0, size.y * 0.4, 0.0)
	dust.emitting = true
	get_tree().create_timer(dust.lifetime + 0.2).timeout.connect(dust.queue_free)
