class_name TarBlast
extends Node3D
## Взрыв смолы (§6.2): огонь коснулся смолы на полу или на враге. Большой урон и удар по стойкости
## всем в радиусе — врагам и герою; враги загораются, соседняя смола взрывается следом.

const RADIUS := 2.5
const DAMAGE := 55.0
const POISE_DAMAGE := 80.0
const KNOCKBACK := 7.0
const BURN_TIME := 2.0
const FLASH_TIME := 0.5
const TONGUES := 8


static func explode(parent: Node, at: Vector3, radius := RADIUS) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var blast := TarBlast.new()
	parent.add_child(blast)
	blast.global_position = at
	blast._go(radius)


func _go(radius: float) -> void:
	var hitbox := Hitbox.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.damage = DAMAGE
	hitbox.poise_damage = POISE_DAMAGE
	hitbox.knockback = KNOCKBACK
	hitbox.heavy = true
	add_child(hitbox)
	var chest := Vector3(0.0, 0.8, 0.0)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Dummy
		if enemy == null or enemy.state == Dummy.State.DEAD:
			continue
		if (enemy.global_position + chest).distance_to(global_position) > radius:
			continue
		enemy.hurtbox.receive_hit(hitbox)
		if is_instance_valid(enemy) and enemy.state != Dummy.State.DEAD:
			enemy.statuses.apply(Statuses.BURNING, BURN_TIME)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not player.is_dead() and (player.global_position + chest).distance_to(global_position) <= radius:
		player.hurtbox.receive_hit(hitbox)
	for node in get_tree().get_nodes_in_group(&"tar"):
		var tar := node as TarPool
		if tar and tar.overlaps(global_position.x - radius, global_position.x + radius, tar.floor_y):
			tar.ignite()
	_show(radius)


func _show(radius: float) -> void:
	HitSpark.spawn(get_parent(), global_position, Color(1.0, 0.5, 0.12), 40)
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 0.5, 0.0), Color(0.1, 0.08, 0.06), 24)
	Sfx.play(&"sword_hit_finisher", global_position, 2.0)
	Sfx.play(&"glass_break", global_position, -6.0)
	Events.noise_made.emit(global_position, 14.0)
	Events.camera_shake_requested.emit(0.4, 0.3)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = radius * 3.0
	light.light_energy = 5.0
	light.position = Vector3(0.0, 0.5, 0.6)
	add_child(light)
	# Огненный шар: языки пламени разлетаются кольцом, растут и гаснут.
	var tween := create_tween().set_parallel(true)
	for i in TONGUES:
		var angle := TAU * float(i) / TONGUES
		var flame := Flame.make(Vector2(radius * 0.7, radius * 1.1))
		flame.position = Vector3(0.0, -0.3, 0.1)
		flame.scale = Vector3.ONE * 0.3
		add_child(flame)
		var to := Vector3(cos(angle) * radius * 0.5, -0.3 + maxf(sin(angle), 0.0) * radius * 0.3, 0.1)
		tween.tween_property(flame, "position", to, FLASH_TIME).set_ease(Tween.EASE_OUT)
		tween.tween_property(flame, "scale", Vector3.ONE, FLASH_TIME * 0.4).set_ease(Tween.EASE_OUT)
		tween.tween_property(flame, "fade", 0.0, FLASH_TIME).set_delay(FLASH_TIME * 0.3)
	tween.tween_property(light, "light_energy", 0.0, FLASH_TIME * 1.4)
	tween.chain().tween_callback(queue_free)
