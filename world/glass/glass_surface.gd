class_name GlassSurface
extends StaticBody3D
## Стекло — главная поверхность мира (§5). Одна сцена на все роли:
## - PANEL — разбиваемая перегородка: за ней сундук, засада или ловушка (§5.1);
## - SLIDE — наклонное стекло, по которому герой скользит. Разбиваемое проваливается
##   под героем по «вниз + прыжок» и всегда показывает сетку трещин (§5.4);
## - CLIMB — стеклянная стена, по которой можно лезть.
## Скаты и стены мечом не разбиваются — только намеренно.
## Блик подсказывает, что за стеклом: подсказка есть всегда (§5.3).

enum GlassType { CLEAR, MURKY, RED_VEIN }
enum Role { PANEL, SLIDE, CLIMB }

const GLASS_SHADER := preload("res://effects/shaders/glass_gleam.gdshader")
const SHARD_COUNT := 12
const SHARD_LIFETIME := 1.4
const SLIDE_CRACKS_HINT := 0.35
const ROLL_CRUMBLE_RATE := 0.5

@export var glass_type := GlassType.CLEAR
@export var role := Role.PANEL
@export var size := Vector3(2.0, 2.0, 0.3)
@export var breakable := true
## Что за стеклом. Эти узлы спят, пока стекло цело, и просыпаются при разбивании.
@export var contents: Array[Node3D] = []
## Видно ли содержимое сквозь стекло (чистое — да, мутное — нет).
@export var show_contents := true
## Трескается под ногами: через столько секунд после первого шага разбивается. 0 — нет.
@export var crumble_time := 0.0
## Через столько секунд разбитое стекло восстанавливается. 0 — остаётся разбитым.
@export var restore_time := 0.0

var _material: ShaderMaterial
var _player: Node3D
var _broken := false
## Время с первого шага по трескающемуся стеклу; < 0 — ещё не наступали.
var _crumble_t := -1.0
var _restore_t := 0.0

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision: CollisionShape3D = $Collision
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_shape: CollisionShape3D = $Hurtbox/Shape


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	var hurt_shape := BoxShape3D.new()
	hurt_shape.size = size + Vector3(0.3, 0.3, 0.3)
	hurtbox_shape.shape = hurt_shape

	_material = ShaderMaterial.new()
	_material.shader = GLASS_SHADER
	_configure_material()
	mesh_instance.material_override = _material

	_join_role_group()
	if role == Role.SLIDE and breakable:
		_material.set_shader_parameter("cracks", SLIDE_CRACKS_HINT)
	if breakable and role == Role.PANEL:
		hurtbox.hurt.connect(func(_hitbox: Hitbox) -> void: shatter())
	else:
		hurtbox.monitorable = false
	for node in contents:
		if is_instance_valid(node):
			_set_awake(node, false)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	_material.set_shader_parameter("player_pos", _player.global_position + Vector3(0, 0.9, 0))


func _physics_process(delta: float) -> void:
	if _broken:
		if restore_time > 0.0:
			_restore_t -= delta
			if _restore_t <= 0.0:
				_try_restore()
	elif crumble_time > 0.0:
		_update_crumble(delta)


func shatter() -> void:
	if _broken:
		return
	_broken = true
	_restore_t = restore_time
	remove_from_group("glass_slide")
	remove_from_group("glass_climb")
	collision.set_deferred("disabled", true)
	hurtbox.set_deferred("monitorable", false)
	mesh_instance.visible = false
	Events.camera_shake_requested.emit(0.2, 0.15)
	_spawn_shards()
	for node in contents:
		if is_instance_valid(node):
			_set_awake(node, true)
			if node.has_method("on_revealed"):
				node.on_revealed()


## Нагрев 0…1 — из стекла выдувается Стеклянный ползун.
func heat(amount: float) -> void:
	_material.set_shader_parameter("heat", clampf(amount, 0.0, 1.0))


## Тень ушла из стекла: мутное становится чистым.
func purify() -> void:
	glass_type = GlassType.CLEAR
	for param in ["tear", "shadow", "red_pulse", "heat"]:
		_material.set_shader_parameter(param, 0.0)
	_configure_material()


## Трескающееся стекло: отсчёт идёт с первого шага и не сбрасывается прыжком.
## Кувырок давит на стекло вдвое слабее — им можно перекатиться через всё стекло.
func _update_crumble(delta: float) -> void:
	if _crumble_t < 0.0:
		if not _player_stands_on_top():
			return
		_crumble_t = 0.0
	var player := _player as Player
	var rolling := player != null and player.state == Player.State.ROLL
	_crumble_t += delta * (ROLL_CRUMBLE_RATE if rolling else 1.0)
	var t := clampf(_crumble_t / crumble_time, 0.0, 1.0)
	_material.set_shader_parameter("cracks", t)
	# Под конец стекло мелко дрожит.
	var shake := 0.03 * maxf(t - 0.6, 0.0) / 0.4
	mesh_instance.position = Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0)
	if t >= 1.0:
		shatter()


func _player_stands_on_top() -> bool:
	var player := _player as Player
	if player == null or not player.is_on_floor():
		return false
	var local := to_local(player.global_position)
	var top := size.y * 0.5
	return absf(local.x) <= size.x * 0.5 + 0.2 and local.y > top - 0.15 and local.y < top + 0.4


func _try_restore() -> void:
	# Не возвращаем стекло прямо в героя — ждём, пока он отойдёт.
	if _player and absf(to_local(_player.global_position).x) < size.x * 0.5 + 0.5 \
			and absf(to_local(_player.global_position).y) < size.y * 0.5 + 1.8:
		_restore_t = 0.2
		return
	_broken = false
	_crumble_t = -1.0
	collision.disabled = false
	if breakable and role == Role.PANEL:
		hurtbox.monitorable = true
	mesh_instance.visible = true
	mesh_instance.position = Vector3.ZERO
	_material.set_shader_parameter("cracks", SLIDE_CRACKS_HINT if role == Role.SLIDE else 0.0)
	_join_role_group()


func _join_role_group() -> void:
	match role:
		Role.SLIDE: add_to_group("glass_slide")
		Role.CLIMB: add_to_group("glass_climb")


func _configure_material() -> void:
	match glass_type:
		GlassType.CLEAR:
			_material.set_shader_parameter("base_color", Color(0.62, 0.8, 0.9, 0.28))
		GlassType.MURKY:
			_material.set_shader_parameter("base_color", Color(0.45, 0.5, 0.48, 0.55))
			_material.set_shader_parameter("tear", 1.0)
			_material.set_shader_parameter("shadow", 1.0)
		GlassType.RED_VEIN:
			_material.set_shader_parameter("base_color", Color(0.7, 0.62, 0.66, 0.35))
			_material.set_shader_parameter("red_pulse", 1.0)


func _set_awake(node: Node3D, awake: bool) -> void:
	node.visible = awake or show_contents
	node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED


func _spawn_shards() -> void:
	var parent := get_parent()
	var shard_material := StandardMaterial3D.new()
	shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_material.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
	shard_material.emission_enabled = true
	shard_material.emission = Color(0.7, 0.85, 1.0)
	shard_material.emission_energy_multiplier = 0.6
	if glass_type == GlassType.RED_VEIN:
		shard_material.emission = Color(1.0, 0.2, 0.15)
	for i in SHARD_COUNT:
		var shard := RigidBody3D.new()
		shard.collision_layer = 0
		shard.collision_mask = 1
		var piece := Vector3(randf_range(0.1, 0.35), randf_range(0.1, 0.35), 0.06)
		var shard_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = piece
		box.material = shard_material
		shard_mesh.mesh = box
		shard.add_child(shard_mesh)
		var shard_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = piece
		shard_shape.shape = shape
		shard.add_child(shard_shape)
		parent.add_child(shard)
		var local := Vector3(randf_range(-0.5, 0.5) * size.x, randf_range(-0.5, 0.5) * size.y, 0.0)
		shard.global_position = global_transform * local
		shard.linear_velocity = Vector3(randf_range(-4, 4), randf_range(1, 6), randf_range(-1.5, 1.5))
		shard.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		var tween := shard.create_tween()
		tween.tween_interval(SHARD_LIFETIME * randf_range(0.6, 1.0))
		tween.tween_property(shard_mesh, "scale", Vector3.ZERO, 0.25)
		tween.tween_callback(shard.queue_free)
