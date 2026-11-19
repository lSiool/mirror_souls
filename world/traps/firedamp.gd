class_name Firedamp
extends Node3D
## Рудничный газ (§8.14): невидимый гремучий газ скопился в штреке. Открытый огонь внутри — фонарь фонарщика
## (и на поясе он горит), огненная стрела, огненная склянка, горящий герой или враг — и газ взрывается: тяжёлый
## удар и огонь всем внутри. Фонарь становится выбором — свет или безопасность. Поджечь газ можно и нарочно,
## издали: огненной стрелой — взрыв выжжет газ и того, кто в нём стоит. Выжженный газ копится снова после отдыха
## у осколка (комната перезагружается). Подсказки честные: у входа мёртвая канарейка в клетке, у потолка — еле
## заметное жёлтое марево. Узел стоит на полу посередине кармана; огонь из группы `open_flame` ищется сам.

signal exploded

const HAZE := Color(0.78, 0.76, 0.45, 0.07)
const IRON := Color(0.1, 0.1, 0.11)
const CANARY := Color(0.85, 0.72, 0.15)
const DAMAGE := 50.0
const BURN_TIME := 3.0
const FLASH_TIME := 0.6

## Ширина, высота и глубина кармана.
@export var size := Vector3(8.0, 4.0, 4.4)
## Где у входа висит клетка с канарейкой (смещение от узла); не нужна — нулевой вектор.
@export var canary_at := Vector3(-4.6, 2.2, -0.9)

var spent := false


func _ready() -> void:
	add_to_group(&"firedamp")
	var haze := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x, size.y * 0.6)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = HAZE
	# Мягкое пятно без краёв: марево, а не плашка.
	material.albedo_texture = PoisonCloud._soft_dot()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	haze.mesh = quad
	haze.name = &"Haze"
	haze.position = Vector3(0.0, size.y * 0.7, -0.6)
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(haze)
	if canary_at != Vector3.ZERO:
		_canary_cage()


func _physics_process(_delta: float) -> void:
	if spent:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player and not player.is_dead() and covers(player.global_position + Vector3(0.0, 1.0, 0.0)):
		if player.lantern_out() or player.statuses.has(Statuses.BURNING):
			ignite()
			return
	for node in get_tree().get_nodes_in_group(&"open_flame"):
		var flame := node as Node3D
		if flame and flame.is_inside_tree() and covers(flame.global_position):
			ignite()
			return
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Dummy
		if enemy and enemy.state != Dummy.State.DEAD and enemy.statuses.has(Statuses.BURNING) \
				and covers(enemy.global_position + Vector3(0.0, 0.8, 0.0)):
			ignite()
			return


## Внутри ли кармана точка (с небольшим запасом по краям).
func covers(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= size.x * 0.5 + 0.3 and local.y >= -0.3 and local.y <= size.y + 0.3 and absf(local.z) <= size.z * 0.5


## Взрыв: тяжёлый удар и огонь всем внутри кармана, вспышка вдоль всего штрека. Газ выжжен до отдыха.
func ignite() -> void:
	if spent:
		return
	spent = true
	var hitbox := Hitbox.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.damage = DAMAGE
	hitbox.poise_damage = 80.0
	hitbox.knockback = 8.0
	hitbox.heavy = true
	add_child(hitbox)
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Dummy
		if enemy and enemy.state != Dummy.State.DEAD and covers(enemy.global_position + Vector3(0.0, 0.8, 0.0)):
			enemy.hurtbox.receive_hit(hitbox)
			if is_instance_valid(enemy) and enemy.state != Dummy.State.DEAD:
				enemy.statuses.apply(Statuses.BURNING, BURN_TIME)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player and not player.is_dead() and covers(player.global_position + Vector3(0.0, 1.0, 0.0)):
		player.hurtbox.receive_hit(hitbox)
		player.statuses.apply(Statuses.BURNING, BURN_TIME)
	(get_node(^"Haze") as Node3D).visible = false
	_flash()
	exploded.emit()


func _flash() -> void:
	Sfx.play(&"gas_blast", global_position + Vector3(0.0, size.y * 0.5, 0.0))
	Events.noise_made.emit(global_position, 20.0)
	Events.camera_shake_requested.emit(0.6, 0.45)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = size.x * 1.2
	light.light_energy = 6.0
	light.position = Vector3(0.0, size.y * 0.5, 0.8)
	add_child(light)
	var tween := create_tween().set_parallel(true)
	var tongues := maxi(int(size.x / 1.2), 3)
	for i in tongues:
		var x := -size.x * 0.5 + size.x * (i + 0.5) / tongues
		var flame := Flame.make(Vector2(1.4, size.y * 0.9))
		flame.position = Vector3(x, 0.0, 0.1)
		flame.scale = Vector3.ONE * 0.3
		add_child(flame)
		tween.tween_property(flame, "scale", Vector3.ONE, FLASH_TIME * 0.35).set_delay(0.03 * i).set_ease(Tween.EASE_OUT)
		tween.tween_property(flame, "fade", 0.0, FLASH_TIME).set_delay(FLASH_TIME * 0.4 + 0.03 * i)
		HitSpark.spawn(get_parent(), global_position + Vector3(x, size.y * 0.5, 0.3), Color(1.0, 0.55, 0.15), 12)
	tween.tween_property(light, "light_energy", 0.0, FLASH_TIME * 1.6)


## Клетка с мёртвой канарейкой на крюке у входа: забойщики знали, что здесь газ.
func _canary_cage() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	var bird := StandardMaterial3D.new()
	bird.albedo_color = CANARY
	var cage := Node3D.new()
	cage.name = &"CanaryCage"
	cage.position = canary_at
	add_child(cage)
	for i in 4:
		var bar := MeshInstance3D.new()
		var bar_box := BoxMesh.new()
		bar_box.size = Vector3(0.02, 0.36, 0.02)
		bar_box.material = iron
		bar.mesh = bar_box
		bar.position = Vector3(0.12 * (1 if i % 2 else -1), 0.0, 0.12 * (1 if i < 2 else -1))
		cage.add_child(bar)
	for y: float in [-0.18, 0.18]:
		var ring := MeshInstance3D.new()
		var ring_box := BoxMesh.new()
		ring_box.size = Vector3(0.28, 0.02, 0.28)
		ring_box.material = iron
		ring.mesh = ring_box
		ring.position.y = y
		cage.add_child(ring)
	var hook := MeshInstance3D.new()
	var hook_box := BoxMesh.new()
	hook_box.size = Vector3(0.02, 0.5, 0.02)
	hook_box.material = iron
	hook.mesh = hook_box
	hook.position.y = 0.43
	cage.add_child(hook)
	# Птица лежит на дне клетки лапками вверх.
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.06
	body_mesh.height = 0.1
	body_mesh.material = bird
	body.mesh = body_mesh
	body.scale = Vector3(1.5, 1.0, 1.0)
	body.position = Vector3(0.0, -0.13, 0.0)
	cage.add_child(body)
