class_name Thrown
extends Node3D
## Брошенный расходник (§6.2): нож, топорик или склянка — летит дугой по своим данным (ConsumableData).
## - враг — урон и стойкость; мёртвого пролетает насквозь;
## - склянка разбивается обо что угодно: вспышка задевает всех врагов в радиусе, на месте
##   остаётся её зона (FlaskZone: огненная лужа, ядовитое облако, кислота, смола, свет);
## - стекло нож и топорик не ломают — звякают и отскакивают вниз;
## - остальное — нож втыкается, торчит и исчезает. Любой удар не во врага — шум, как у стрелы.

## Слои: мир, враги, мишени (как у стрелы). Стёкла-перегородки не задеваем.
const MASK := 1 | 4 | 32
## Слой врагов — для вспышки склянки.
const ENEMY_MASK := 4
const LIFETIME := 4.0
const STUCK_TIME := 1.2
const NOISE_RADIUS := 8.0
const FLASH_TIME := 0.35

var data: ConsumableData
var velocity := Vector3.ZERO
var stuck := false

var _age := 0.0
var _hitbox: Hitbox
var _look: MeshInstance3D
var _exclude: Array[RID] = []


static func spawn(parent: Node, at: Vector3, vel: Vector3, item: ConsumableData, damage_mult: float) -> Thrown:
	var thrown := Thrown.new()
	thrown.data = item
	thrown._build(damage_mult)
	parent.add_child(thrown)
	thrown.global_position = at
	thrown.velocity = vel
	thrown._orient()
	return thrown


## Заглушка предмета: брусок клинка или шар склянки. Её же герой держит в руке перед броском.
static func make_look(item: ConsumableData) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.look_color
	if item.look_metal:
		mat.metallic = 0.85
		mat.roughness = 0.35
	var look := MeshInstance3D.new()
	if item.burst_radius > 0.0:
		var ball := SphereMesh.new()
		ball.radius = item.look_size.x
		ball.height = item.look_size.x * 2.0
		ball.material = mat
		look.mesh = ball
		# Горящий фитиль: склянку видно в тёмной комнате.
		mat.emission_enabled = true
		mat.emission = item.burst_color
		mat.emission_energy_multiplier = 0.6
		if item.zone == ConsumableData.Zone.FIRE:
			var wick := Flame.make(Vector2(item.look_size.x * 1.6, item.look_size.x * 2.6))
			wick.position.y = item.look_size.x * 0.8
			look.add_child(wick)
	else:
		var box := BoxMesh.new()
		box.size = item.look_size
		box.material = mat
		look.mesh = box
	return look


func _build(damage_mult: float) -> void:
	_look = make_look(data)
	add_child(_look)
	# Хитбокс ничего не ищет сам — им предмет «представляется» хёртбоксу врага.
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 0
	_hitbox.damage = data.damage * damage_mult
	_hitbox.poise_damage = data.poise_damage
	_hitbox.knockback = data.knockback
	add_child(_hitbox)


func _physics_process(delta: float) -> void:
	_age += delta
	if stuck:
		if _age >= STUCK_TIME:
			queue_free()
		return
	if _age >= LIFETIME:
		queue_free()
		return
	velocity.y -= data.gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_orient()
		if data.spin != 0.0:
			_look.rotation.z -= data.spin * TAU * delta * signf(velocity.x)
		return
	_on_hit(hit)


func _on_hit(hit: Dictionary) -> void:
	var collider: Object = hit.collider
	var at: Vector3 = hit.position
	var hurtbox := collider as Hurtbox
	if collider is Dummy:
		hurtbox = (collider as Dummy).hurtbox
	if hurtbox and hurtbox.owner is Dummy and (hurtbox.owner as Dummy).state == Dummy.State.DEAD:
		_exclude.append(hit.rid)
		return
	if data.burst_radius > 0.0:
		_burst(at)
		return
	if hurtbox:
		hurtbox.receive_hit(_hitbox)
		HitSpark.spawn(get_parent(), at, Color(1.0, 0.85, 0.6), 8)
		Sfx.play(&"sword_hit", at, -4.0)
		queue_free()
		return
	if collider is ArrowTarget:
		(collider as ArrowTarget).arrow_hit(self)
		Sfx.play(&"arrow_hit_wood", at)
		queue_free()
		return
	Events.noise_made.emit(at, NOISE_RADIUS)
	if collider is GlassSurface:
		# Стекло ножом не разбить: звякнул и падает.
		HitSpark.spawn(get_parent(), at, Color(0.8, 0.95, 1.0), 6)
		Sfx.play(&"arrow_ricochet_glass", at)
		velocity = Vector3(-velocity.x * 0.2, -1.0, 0.0)
		global_position = at + (hit.normal as Vector3) * 0.05
		_exclude.append(hit.rid)
		return
	Sfx.play(&"arrow_hit_wood", at, -3.0)
	global_position = at
	stuck = true
	_age = 0.0


## Склянка разбилась: вспышка задевает каждого живого врага в радиусе один раз — урон
## (святая — нежити во много раз больнее, с крестом из света) и состояние склянки
## (огонь, кислота, смола); дальше на месте остаётся её зона (FlaskZone).
func _burst(at: Vector3) -> void:
	global_position = at
	var base_damage := _hitbox.damage
	for enemy in _enemies_in(at, data.burst_radius):
		var holy := data.zone == ConsumableData.Zone.HOLY and enemy.unholy
		_hitbox.damage = base_damage * (data.holy_mult if holy else 1.0)
		if _hitbox.damage > 0.0:
			enemy.hurtbox.receive_hit(_hitbox)
		if holy:
			HolyCross.spawn(get_parent(), enemy.global_position, enemy.body_height())
		if is_instance_valid(enemy) and enemy.state != Dummy.State.DEAD:
			var status := _burst_status()
			if status != &"":
				enemy.statuses.apply(status, data.status_time)
	_hitbox.damage = base_damage
	# Брызги кислоты и смолы задевают и героя, если он стоял рядом.
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and (player.global_position + Vector3(0.0, 0.8, 0.0)).distance_to(at) <= data.burst_radius:
		match data.zone:
			ConsumableData.Zone.ACID: player.statuses.apply(Statuses.CORRODED, data.status_time * 0.5)
			ConsumableData.Zone.TAR: player.statuses.apply(Statuses.TAR, 3.0)
	if data.zone == ConsumableData.Zone.FIRE:
		for node in get_tree().get_nodes_in_group(&"tar"):
			var tar := node as TarPool
			if tar and tar.overlaps(at.x - data.burst_radius, at.x + data.burst_radius, tar.floor_y):
				tar.ignite()
	FlaskZone.spawn(get_parent(), at, data)
	HitSpark.spawn(get_parent(), at, data.burst_color, 30)
	HitSpark.spawn(get_parent(), at + Vector3(0.0, 0.4, 0.0), data.burst_color.lightened(0.4), 16)
	Sfx.play(&"glass_break", at, -2.0)
	Events.noise_made.emit(at, NOISE_RADIUS * 1.5)
	Events.camera_shake_requested.emit(0.15, 0.15)
	var flash := OmniLight3D.new()
	flash.light_color = data.burst_color
	flash.omni_range = data.burst_radius * 2.5
	flash.light_energy = 3.0
	get_parent().add_child(flash)
	flash.global_position = at + Vector3(0.0, 0.3, 0.3)
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, FLASH_TIME)
	fade.tween_callback(flash.queue_free)
	queue_free()


## Живые враги, чьё тело или хёртбокс в шаре вспышки.
func _enemies_in(at: Vector3, radius: float) -> Array[Dummy]:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var found_enemies: Array[Dummy] = []
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var enemy := found.collider as Dummy
		if enemy == null and found.collider is Hurtbox:
			enemy = (found.collider as Hurtbox).owner as Dummy
		if enemy == null or enemy in found_enemies or enemy.state == Dummy.State.DEAD:
			continue
		found_enemies.append(enemy)
	return found_enemies


## Состояние, которое вспышка вешает на задетого: яд — только облаком, свет — без состояния.
func _burst_status() -> StringName:
	match data.zone:
		ConsumableData.Zone.FIRE: return Statuses.BURNING
		ConsumableData.Zone.ACID: return Statuses.CORRODED
		ConsumableData.Zone.TAR: return Statuses.TAR
	return &""


func _orient() -> void:
	if velocity.length_squared() > 0.001:
		rotation = Vector3(0.0, 0.0, atan2(velocity.y, velocity.x))
