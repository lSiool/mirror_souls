class_name HangingProp
extends Node3D
## Подвес, который сбивают стрелами (§6.2): люстра на верёвке, сталактит, осколок у потолка.
## Падая, бьёт всех под собой. Приземлившись, становится платформой или разбивается.
## Материал задаётся биомом: ледяные, глиняные, гипсовые, соляные, лавовые сталактиты.
## Начало координат — точка подвеса тела (верх люстры или основание сталактита).

enum Kind { CHANDELIER, STALACTITE, CEILING_SHARD }
enum Matter { GLASS, ICE, CLAY, GYPSUM, SALT, LAVA, BRASS }

const FALL_GRAVITY := 30.0
const WORLD_MASK := 1

@export var kind := Kind.CHANDELIER
@export var matter := Matter.BRASS
## Сколько стрел нужно, чтобы сбить.
@export var hits_required := 2
## Длина верёвки над телом (0 — висит прямо на потолке).
@export var rope_length := 3.0
## Ширина и высота тела.
@export var size := Vector2(3.6, 1.6)
@export var fall_damage := 40.0
## Упав, становится платформой (люстра) или разбивается (сталактит).
@export var becomes_platform := true

var fallen := false
var landed := false

var _fall_speed := 0.0
var _exclude: Array[RID] = []
var _body: Node3D
var _rope: MeshInstance3D
var _target: ArrowTarget
var _hitbox: Hitbox
var _material: StandardMaterial3D


func _ready() -> void:
	_material = _make_material()
	_body = Node3D.new()
	add_child(_body)
	match kind:
		Kind.CHANDELIER: _build_chandelier()
		Kind.STALACTITE: _build_spike(false)
		Kind.CEILING_SHARD: _build_spike(true)
	if rope_length > 0.0:
		_rope = MeshInstance3D.new()
		var rope_mesh := CylinderMesh.new()
		rope_mesh.top_radius = 0.03
		rope_mesh.bottom_radius = 0.03
		rope_mesh.height = rope_length
		var rope_mat := StandardMaterial3D.new()
		rope_mat.albedo_color = Color(0.35, 0.28, 0.2)
		rope_mesh.material = rope_mat
		_rope.mesh = rope_mesh
		_rope.position.y = rope_length * 0.5
		add_child(_rope)

	_target = ArrowTarget.new()
	_target.hits_required = hits_required
	_target.add_child(_box_shape(Vector3(size.x, size.y + rope_length, 1.2), \
		Vector3(0.0, (rope_length - size.y) * 0.5, 0.0)))
	add_child(_target)
	_target.struck.connect(_on_struck)
	_target.triggered.connect(fall)

	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = (1 << 1) | (1 << 2)
	_hitbox.damage = fall_damage
	_hitbox.poise_damage = 100.0
	_hitbox.heavy = true
	_hitbox.knockback = 4.0
	_hitbox.add_child(_box_shape(Vector3(size.x, size.y, 1.2), Vector3(0.0, -size.y * 0.5, 0.0)))
	_body.add_child(_hitbox)


func _physics_process(delta: float) -> void:
	if not fallen or landed:
		return
	_fall_speed += FALL_GRAVITY * delta
	var step := _fall_speed * delta
	var bottom := _body.global_position + Vector3(0.0, -size.y, 0.0)
	var to := bottom + Vector3(0.0, -step, 0.0)
	var query := PhysicsRayQueryParameters3D.create(bottom, to, WORLD_MASK, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Тяжёлый подвес пробивает хрупкое стекло под собой и падает дальше.
	var glass := hit.get("collider") as GlassSurface
	if glass and glass.breakable and glass.role == GlassSurface.Role.PANEL:
		glass.shatter()
		_exclude.append(hit.rid)
		return
	if hit.is_empty():
		_body.global_position.y -= step
		return
	_body.global_position.y = hit.position.y + size.y
	_land()


## Сбит: верёвка рвётся, тело падает.
func fall() -> void:
	if fallen:
		return
	fallen = true
	if _rope:
		_rope.visible = false
	_hitbox.active = true
	_target.set_deferred("monitorable", false)


func _land() -> void:
	landed = true
	Events.camera_shake_requested.emit(0.35, 0.25)
	var impact := _body.global_position + Vector3(0.0, -size.y, 0.3)
	HitSpark.spawn(get_parent(), impact, _material.albedo_color, 30)
	# Хитбокс держим ещё мгновение: кто оказался под подвесом в момент удара — получит.
	get_tree().create_timer(0.1).timeout.connect(func() -> void: _hitbox.active = false)
	if becomes_platform:
		var platform := StaticBody3D.new()
		platform.collision_layer = 1
		platform.collision_mask = 0
		platform.add_child(_box_shape(Vector3(size.x, size.y, 2.0), Vector3(0.0, -size.y * 0.5, 0.0)))
		_body.add_child(platform)
	else:
		_body.visible = false
		get_tree().create_timer(0.15).timeout.connect(queue_free)


func _on_struck(_hits: int) -> void:
	# Попадание, но ещё держится — качнулся.
	if fallen:
		return
	var tween := create_tween()
	tween.tween_property(_body, "rotation:z", 0.12, 0.08)
	tween.tween_property(_body, "rotation:z", -0.08, 0.12)
	tween.tween_property(_body, "rotation:z", 0.0, 0.12)


func _build_chandelier() -> void:
	var radius := size.x * 0.5
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	torus.material = _material
	ring.mesh = torus
	ring.position.y = -size.y + 0.1
	_body.add_child(ring)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.08
	hub_mesh.bottom_radius = 0.14
	hub_mesh.height = size.y
	hub_mesh.material = _material
	hub.mesh = hub_mesh
	hub.position.y = -size.y * 0.5
	_body.add_child(hub)
	var candle_mat := StandardMaterial3D.new()
	candle_mat.albedo_color = Color(1.0, 0.85, 0.5)
	candle_mat.emission_enabled = true
	candle_mat.emission = Color(1.0, 0.7, 0.3)
	candle_mat.emission_energy_multiplier = 2.0
	for i in 6:
		var angle := TAU * i / 6.0
		var candle := MeshInstance3D.new()
		var candle_mesh := CylinderMesh.new()
		candle_mesh.top_radius = 0.05
		candle_mesh.bottom_radius = 0.05
		candle_mesh.height = 0.3
		candle_mesh.material = candle_mat
		candle.mesh = candle_mesh
		var r := radius - 0.06
		candle.position = Vector3(cos(angle) * r, -size.y + 0.3, sin(angle) * r)
		_body.add_child(candle)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.45)
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	glow.position.y = -size.y + 0.4
	_body.add_child(glow)


func _build_spike(sharp_shard: bool) -> void:
	var spike := MeshInstance3D.new()
	if sharp_shard:
		var prism := PrismMesh.new()
		prism.size = Vector3(size.x, size.y, 0.3)
		prism.material = _material
		spike.mesh = prism
		spike.rotation.z = PI
	else:
		var cone := CylinderMesh.new()
		cone.top_radius = size.x * 0.5
		cone.bottom_radius = 0.0
		cone.height = size.y
		cone.radial_segments = 7
		cone.material = _material
		spike.mesh = cone
	spike.position.y = -size.y * 0.5
	_body.add_child(spike)


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var colors := {
		Matter.GLASS: Color(0.75, 0.88, 1.0, 0.7),
		Matter.ICE: Color(0.7, 0.9, 1.0, 0.85),
		Matter.CLAY: Color(0.55, 0.35, 0.25),
		Matter.GYPSUM: Color(0.9, 0.9, 0.85),
		Matter.SALT: Color(0.95, 0.92, 0.95),
		Matter.LAVA: Color(0.3, 0.1, 0.05),
		Matter.BRASS: Color(0.75, 0.6, 0.3),
	}
	mat.albedo_color = colors[matter]
	mat.roughness = 0.4
	if matter in [Matter.GLASS, Matter.ICE]:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05
	if matter == Matter.BRASS:
		mat.metallic = 0.8
	if matter == Matter.LAVA:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.05)
		mat.emission_energy_multiplier = 1.5
	return mat


func _box_shape(box_size: Vector3, at: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = box_size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = at
	return node
