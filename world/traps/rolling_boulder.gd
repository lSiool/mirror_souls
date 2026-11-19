class_name RollingBoulder
extends Node3D
## Катящийся валун (§8.14): ждёт наверху уклона; спуск (TrapTrigger) — сперва гул, дрожь и пыль с потолка
## (start_delay), потом срывается и катится вслед за героем, набирая скорость, — давит тяжело и сбивает с ног.
## Как уйти: перепрыгнуть, перекатиться в последний миг, спрыгнуть в яму поуже валуна (он её перекатывает),
## забраться выше. Врагов на пути давит тоже. Упёрся в стену — раскалывается; слабую стену (WeakWall) проламывает
## и открывает новый ход. В копях вместо валуна — сорвавшаяся вагонетка (look = CART).
## Узел стоит там, где валун ждёт: на земле, валун — над ней.

enum Look { BOULDER, CART }

const WORLD_MASK := 1
const STONE := Color(0.24, 0.22, 0.2)
const RUST := Color(0.3, 0.17, 0.1)
const IRON := Color(0.1, 0.1, 0.11)

@export var look := Look.BOULDER
@export var radius := 1.1
## Куда катится: +1 — вправо, −1 — влево.
@export var direction := 1.0
@export var max_speed := 9.0
@export var acceleration := 7.0
@export var damage := 60.0
## Сколько гудит перед срывом.
@export var start_delay := 1.2
## Дальше этого (по x от старта) не катится — раскалывается.
@export var travel_limit := 60.0

var rolling := false
var done := false
var speed := 0.0

var _wait := -1.0
var _body: Node3D
var _wheels: Array[Node3D] = []
var _hitbox: Hitbox
var _start_x := 0.0
var _fall := 0.0


func _ready() -> void:
	_body = Node3D.new()
	_body.name = &"Body"
	_body.position.y = radius
	add_child(_body)
	if look == Look.BOULDER:
		_build_boulder()
	else:
		_build_cart()
	_hitbox = Hitbox.new()
	_hitbox.name = &"Hitbox"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = TrapTrigger.LAYER_PLAYER | TrapTrigger.LAYER_HITTABLE
	_hitbox.damage = damage
	_hitbox.poise_damage = 80.0
	_hitbox.knockback = 10.0
	_hitbox.heavy = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius * 0.95
	shape.shape = sphere
	_hitbox.add_child(shape)
	_hitbox.position.y = radius
	add_child(_hitbox)


## Спуск: гул и пыль, через start_delay — сорвался.
func fire() -> void:
	if rolling or done or _wait >= 0.0:
		return
	_wait = start_delay
	_start_x = global_position.x
	Sfx.play(&"boulder_rumble", global_position + Vector3(0.0, radius, 0.0))
	Events.camera_shake_requested.emit(0.15, start_delay)
	_dust()


func _physics_process(delta: float) -> void:
	if done:
		return
	if _wait >= 0.0 and not rolling:
		_wait -= delta
		if _wait < 0.0:
			rolling = true
			_hitbox.active = true
		return
	if not rolling:
		return
	speed = minf(speed + acceleration * delta, max_speed)
	var step := direction * speed * delta
	# Впереди стена: слабую — проломить, крепкую — расколоться о неё.
	var ahead := _wall_ahead(absf(step) + radius)
	if ahead:
		if ahead.has_method(&"smash"):
			ahead.smash()
		else:
			_shatter()
			return
	global_position.x += step
	if look == Look.BOULDER:
		_body.rotation.z -= step / radius
	for hub in _wheels:
		hub.rotation.z -= step / 0.22
	# По земле: высота — по самой высокой из трёх точек под валуном (узкую яму он перекатывает).
	var ground := _ground()
	if is_nan(ground) or ground < global_position.y - 0.05:
		_fall += 18.0 * delta
		global_position.y -= _fall * delta
		if not is_nan(ground) and global_position.y <= ground:
			global_position.y = ground
			_fall = 0.0
	else:
		global_position.y = ground
		_fall = 0.0
	if absf(global_position.x - _start_x) > travel_limit or global_position.y < -20.0:
		_shatter()


func _ground() -> float:
	var best := NAN
	for k: float in [-0.9, 0.0, 0.9]:
		var x := global_position.x + k * radius
		var from := Vector3(x, global_position.y + radius + 0.6, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -radius - 4.0, 0.0), WORLD_MASK)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var y: float = (hit.position as Vector3).y
			best = y if is_nan(best) else maxf(best, y)
	return best


func _wall_ahead(reach: float) -> Object:
	var from := global_position + Vector3(0.0, radius * 1.1, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(direction * reach, 0.0, 0.0), WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit.collider


## Раскололся: осколки, пыль, гул затих.
func _shatter() -> void:
	done = true
	rolling = false
	_hitbox.active = false
	_body.visible = false
	Sfx.play(&"boulder_crash", global_position + Vector3(0.0, radius, 0.0))
	Events.camera_shake_requested.emit(0.35, 0.3)
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, radius, 0.4), STONE.lightened(0.3), 30)


## Пыль с потолка над валуном, пока гудит.
func _dust() -> void:
	var dust := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.55, 0.5, 0.42, 0.6)
	quad.material = material
	dust.mesh = quad
	dust.one_shot = true
	dust.amount = 40
	dust.lifetime = 1.6
	dust.explosiveness = 0.2
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(radius * 2.0, 0.2, 1.0)
	dust.gravity = Vector3(0.0, -4.0, 0.0)
	dust.position = Vector3(0.0, radius * 2.0 + 2.0, 0.0)
	add_child(dust)
	dust.emitting = true


func _build_boulder() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE
	stone.roughness = 0.95
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	sphere.material = stone
	ball.mesh = sphere
	_body.add_child(ball)
	# Сколы и выступы — чтобы было видно, что он катится.
	for i in 4:
		var lump := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(radius * 0.7, radius * 0.5, radius * 0.6)
		box.material = stone
		lump.mesh = box
		var a := TAU * i / 4.0
		lump.position = Vector3(cos(a), sin(a), 0.0) * radius * 0.75
		lump.rotation.z = a
		_body.add_child(lump)


func _build_cart() -> void:
	var rust := StandardMaterial3D.new()
	rust.albedo_color = RUST
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	# Вагонетка не катится кувырком: колёса крутятся, короб — нет.
	_body.position.y = 0.0
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.7, 1.0, 1.2)
	box_mesh.material = rust
	box.mesh = box_mesh
	box.position.y = 0.75
	_body.add_child(box)
	var ore := MeshInstance3D.new()
	var ore_mesh := SphereMesh.new()
	ore_mesh.radius = 0.55
	ore_mesh.height = 0.9
	ore_mesh.material = iron
	ore.mesh = ore_mesh
	ore.position.y = 1.25
	_body.add_child(ore)
	for dx: float in [-0.55, 0.55]:
		var hub := Node3D.new()
		hub.position = Vector3(dx, 0.22, 0.62)
		_body.add_child(hub)
		var wheel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.22
		cylinder.bottom_radius = 0.22
		cylinder.height = 0.1
		cylinder.material = iron
		wheel.mesh = cylinder
		wheel.rotation.x = PI * 0.5
		hub.add_child(wheel)
		var spoke := MeshInstance3D.new()
		var spoke_box := BoxMesh.new()
		spoke_box.size = Vector3(0.4, 0.05, 0.12)
		spoke_box.material = rust
		spoke.mesh = spoke_box
		hub.add_child(spoke)
		_wheels.append(hub)
