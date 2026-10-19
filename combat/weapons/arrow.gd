class_name Arrow
extends Node3D
## Стрела (§6.2): снаряд с гравитацией. Летит и за пределами экрана.
## - враг — урон;
## - стекло не ломает — отскакивает (рикошет);
## - мягкое (группа "arrow_soft") — втыкается и становится колышком-ступенькой;
## - мишень (ArrowTarget) — засчитывает попадание;
## - камень — торчит и исчезает. Любой удар не во врага — шум, на который приходят враги.

## Слои: мир, враги, мишени. Стёкла-перегородки (хёртбоксы стекла) не задеваем.
const MASK := 1 | 4 | 32
const LIFETIME := 5.0
const MAX_RICOCHETS := 2
const GRAVITY := 9.0
const NOISE_RADIUS := 9.0
const STUCK_TIME := 1.0

var velocity := Vector3.ZERO
var ricochets := 0
var stuck := false

var _age := 0.0
var _hitbox: Hitbox
var _exclude: Array[RID] = []


static func spawn(
		parent: Node, at: Vector3, vel: Vector3, damage: float, poise_damage: float
) -> Arrow:
	var arrow := Arrow.new()
	parent.add_child(arrow)
	arrow.global_position = at
	arrow.velocity = vel
	arrow._hitbox.damage = damage
	arrow._hitbox.poise_damage = poise_damage
	arrow._orient()
	return arrow


func _init() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.25)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.75, 0.035, 0.035)
	shaft_mesh.material = wood
	shaft.mesh = shaft_mesh
	shaft.position.x = -0.375
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.1, 0.07, 0.07)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.8, 0.82, 0.86)
	steel.metallic = 0.9
	tip_mesh.material = steel
	tip.mesh = tip_mesh
	add_child(tip)
	# Хитбокс ничего не ищет сам — им стрела «представляется» хёртбоксу врага.
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 0
	_hitbox.knockback = 3.0
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
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_orient()
		return
	_on_hit(hit)


func _on_hit(hit: Dictionary) -> void:
	var collider: Object = hit.collider
	var at: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var hurtbox := collider as Hurtbox
	if collider is Dummy:
		hurtbox = (collider as Dummy).hurtbox
	if hurtbox:
		var enemy := hurtbox.owner as Dummy
		if enemy and enemy.state == Dummy.State.DEAD:
			_exclude.append(hit.rid)
			return
		hurtbox.receive_hit(_hitbox)
		HitSpark.spawn(get_parent(), at, Color(1.0, 0.85, 0.6), 8)
		queue_free()
		return
	if collider is ArrowTarget:
		(collider as ArrowTarget).arrow_hit(self)
		HitSpark.spawn(get_parent(), at, Color(1.0, 0.9, 0.6), 10)
		queue_free()
		return
	if collider is GlassSurface and ricochets < MAX_RICOCHETS:
		# Стекло стрелой не ломаем — стрела звонко отскакивает.
		ricochets += 1
		velocity = velocity.bounce(normal) * 0.8
		global_position = at + normal * 0.05
		_orient()
		HitSpark.spawn(get_parent(), at, Color(0.8, 0.95, 1.0), 8)
		return
	Events.noise_made.emit(at, NOISE_RADIUS)
	if collider is Node and (collider as Node).is_in_group("arrow_soft"):
		ArrowPeg.plant(get_parent(), at, normal)
		queue_free()
		return
	# Камень: стрела торчит и вскоре исчезает.
	global_position = at
	stuck = true
	_age = 0.0


func _orient() -> void:
	if velocity.length_squared() > 0.001:
		rotation = Vector3(0.0, 0.0, atan2(velocity.y, velocity.x))
