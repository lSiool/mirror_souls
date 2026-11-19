class_name CrowFlock
extends Node3D
## Вороны-сторожа (§8.14): сигнализация, а не враг. Стая клюёт на жнивье чуть в глубине кадра, сторож сидит
## на столбе изгороди и вертит головой — косится на героя, когда тот рядом. Пройти шагом можно. Бег, перекат,
## удар, рывок ближе alarm_radius, шум рядом (стрела, брошенный камень) или шаг прямо в стаю — сторож каркает,
## стая с шумом взлетает и улетает. Взлёт — шум (Events.noise_made) радиусом noise_radius: враги идут туда,
## где взлетели птицы (Полудница, Пугало). Вспугнуть стаю можно и нарочно — увести врага от своей тропы.
## Улетевшая стая возвращается после отдыха у осколка (комната перезагружается).
## Узел стоит на земле посередине стаи; птицы — в полосе width по x, по глубине — от z_near до z_far.

signal alarmed

const BLACK := Color(0.035, 0.035, 0.045)
const BEAK := Color(0.16, 0.14, 0.12)
const POST := Color(0.16, 0.12, 0.09)
## Сколько летят, прежде чем скрыться из виду.
const FLIGHT_TIME := 4.0

@export var count := 8
@export var width := 6.0
@export var z_near := -1.8
@export var z_far := -3.6
## Где сидит сторож (смещение от узла) и ставить ли под ним столб изгороди.
@export var sentry_at := Vector3(1.5, 1.4, -1.5)
@export var sentry_post := true
## Ближе этого (по x, от края стаи) громкое действие героя её спугивает; ближе watch_radius сторож следит.
@export var alarm_radius := 7.0
@export var watch_radius := 11.0
## Подошёл ближе этого к любой птице — спугнул и шагом.
@export var startle_radius := 1.6
## Насколько далеко слышен взлёт.
@export var noise_radius := 24.0

var flown := false

var _birds: Array[Node3D] = []
var _heads: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _phase: Array[float] = []
var _velocity: Array[Vector3] = []
var _delay: Array[float] = []
var _sentry: Node3D
var _t := 0.0
var _flight_t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + count
	var black := _material(BLACK, 0.45)
	var beak := _material(BEAK, 0.8)
	for i in count:
		var x := -width * 0.5 + width * (i + 0.5) / count + rng.randf_range(-0.25, 0.25)
		var z := lerpf(z_near, z_far, rng.randf())
		_add_bird(Vector3(x, 0.0, z), 1.0 if rng.randf() < 0.5 else -1.0, rng.randf() * TAU, black, beak)
	if sentry_post:
		var post := MeshInstance3D.new()
		var post_box := BoxMesh.new()
		post_box.size = Vector3(0.16, sentry_at.y, 0.16)
		post_box.material = _material(POST, 0.9)
		post.mesh = post_box
		post.position = Vector3(sentry_at.x, sentry_at.y * 0.5, sentry_at.z)
		add_child(post)
	_sentry = _add_bird(sentry_at, -1.0, 0.0, black, beak)
	Events.noise_made.connect(_on_noise)


func _physics_process(delta: float) -> void:
	_t += delta
	if flown:
		_fly(delta)
		return
	# Клюют: голова то и дело ныряет к земле; сторож не клюёт, а смотрит.
	for i in _birds.size():
		if _birds[i] == _sentry:
			continue
		var peck := pow(maxf(sin(_t * 2.6 + _phase[i]), 0.0), 6.0)
		_heads[i].rotation.z = -1.1 * peck
	var hero := get_tree().get_first_node_in_group(&"player") as Player
	if hero == null or hero.is_dead():
		return
	var gap := maxf(absf(hero.global_position.x - global_position.x) - width * 0.5, 0.0)
	var sentry_head := _heads[_birds.find(_sentry)]
	if gap < watch_radius:
		# Сторож поворачивает голову к герою.
		var toward := signf(hero.global_position.x - _sentry.global_position.x) * _sentry.scale.x
		sentry_head.rotation.y = lerpf(sentry_head.rotation.y, 0.0 if toward > 0.0 else PI, minf(delta * 6.0, 1.0))
	if gap < alarm_radius and _loud(hero):
		alarm(hero.global_position)
		return
	for bird in _birds:
		if bird.global_position.distance_to(hero.global_position) < startle_radius:
			alarm(hero.global_position)
			return


## Вспугнуть: сторож каркает, стая взлетает прочь от того, что её спугнуло; взлёт слышат враги.
func alarm(from: Vector3) -> void:
	if flown:
		return
	flown = true
	Sfx.play(&"crow_caw", _sentry.global_position)
	Sfx.play(&"crow_flap", global_position + Vector3(0.0, 0.5, 0.0))
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729 + count
	for i in _birds.size():
		_velocity[i] = Vector3(away * rng.randf_range(1.5, 4.0), rng.randf_range(3.0, 5.0), rng.randf_range(-2.4, -0.6))
		_delay[i] = 0.0 if _birds[i] == _sentry else rng.randf_range(0.05, 0.4)
		_birds[i].scale.x = away
	Events.noise_made.emit(global_position, noise_radius)
	alarmed.emit()


## Громко ли герой: бег, перекат, удар, удар сверху, заряд, скольжение.
func _loud(hero: Player) -> bool:
	return hero.sprinting or hero.state in [Player.State.ROLL, Player.State.ATTACK, Player.State.PLUNGE, Player.State.CHARGE,
		Player.State.SLIDE]


## Шум рядом со стаей (стрела воткнулась, камень упал) — взлетают.
func _on_noise(at: Vector3, _radius: float) -> void:
	if flown or not is_inside_tree():
		return
	var gap := maxf(absf(at.x - global_position.x) - width * 0.5, 0.0)
	if gap < 3.5 and absf(at.y - global_position.y) < 4.0:
		alarm(at)


func _fly(delta: float) -> void:
	_flight_t += delta
	if _flight_t > FLIGHT_TIME:
		for bird in _birds:
			bird.visible = false
		set_physics_process(false)
		return
	for i in _birds.size():
		if _flight_t < _delay[i]:
			continue
		_velocity[i].y += 1.2 * delta
		_birds[i].position += _velocity[i] * delta
		_heads[i].rotation.z = 0.2
		var flap := sin((_flight_t - _delay[i]) * 26.0 + _phase[i]) * 1.1
		_wings[i * 2].rotation.x = flap
		_wings[i * 2 + 1].rotation.x = -flap


## Ворона: тело-капля, голова с клювом (поворачивается и клюёт), хвост, сложенные крылья.
func _add_bird(at: Vector3, facing: float, phase: float, black: Material, beak: Material) -> Node3D:
	var bird := Node3D.new()
	bird.name = "Crow%d" % _birds.size()
	bird.position = at
	bird.scale.x = facing
	add_child(bird)
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.11
	body_mesh.height = 0.2
	body_mesh.material = black
	body.mesh = body_mesh
	body.scale = Vector3(1.5, 1.0, 1.0)
	body.position = Vector3(0.0, 0.17, 0.0)
	body.rotation.z = 0.25
	bird.add_child(body)
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.16, 0.03, 0.08)
	tail_mesh.material = black
	tail.mesh = tail_mesh
	tail.position = Vector3(-0.2, 0.12, 0.0)
	tail.rotation.z = 0.35
	bird.add_child(tail)
	for leg_z: float in [-0.03, 0.03]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.015, 0.09, 0.015)
		leg_mesh.material = beak
		leg.mesh = leg_mesh
		leg.position = Vector3(0.0, 0.045, leg_z)
		bird.add_child(leg)
	var head := Node3D.new()
	head.position = Vector3(0.13, 0.25, 0.0)
	bird.add_child(head)
	var skull := MeshInstance3D.new()
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.06
	skull_mesh.height = 0.12
	skull_mesh.material = black
	skull.mesh = skull_mesh
	head.add_child(skull)
	var bill := MeshInstance3D.new()
	var bill_mesh := BoxMesh.new()
	bill_mesh.size = Vector3(0.09, 0.025, 0.025)
	bill_mesh.material = beak
	bill.mesh = bill_mesh
	bill.position = Vector3(0.08, -0.01, 0.0)
	head.add_child(bill)
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0.0, 0.2, side * 0.07)
		bird.add_child(wing)
		var feather := MeshInstance3D.new()
		var feather_mesh := BoxMesh.new()
		feather_mesh.size = Vector3(0.22, 0.02, 0.2)
		feather_mesh.material = black
		feather.mesh = feather_mesh
		feather.position = Vector3(-0.03, 0.0, side * 0.1)
		wing.add_child(feather)
		_wings.append(wing)
	_birds.append(bird)
	_heads.append(head)
	_phase.append(phase)
	_velocity.append(Vector3.ZERO)
	_delay.append(0.0)
	return bird


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
