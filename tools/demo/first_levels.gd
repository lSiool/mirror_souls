extends Node
## Запись демо первых уровней: бот проходит хижину, горящую улицу, дом с крысами, бой с оборотнем,
## двор часовни, часовню и начало леса. Запуск с записью видео (Movie Maker):
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie D:/Downloads/rec/demo.avi res://tools/demo/first_levels.tscn
## Бот жмёт те же кнопки, что игрок; переходы между комнатами — через двери.

var player: Player
var rooms: RoomManager


func _ready() -> void:
	run()


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(3)
	Input.action_release(action)
	await frames(1)


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "roll", "attack", "interact", "heal"]:
		Input.action_release(a)


## Идёт к точке x; прыгает, если упёрся. Возвращает, дошёл ли.
func walk_to(x: float, limit := 12.0, tolerance := 0.4) -> bool:
	var time := 0.0
	var stuck := 0.0
	var last := player.global_position.x
	while absf(player.global_position.x - x) > tolerance and time < limit:
		var dir := "move_right" if x > player.global_position.x else "move_left"
		Input.action_release("move_left" if dir == "move_right" else "move_right")
		Input.action_press(dir)
		await frames(1)
		time += 1.0 / 60.0
		stuck = stuck + 1.0 / 60.0 if absf(player.global_position.x - last) < 0.01 else 0.0
		last = player.global_position.x
		if stuck > 0.25:
			await tap("jump")
			stuck = 0.0
	release_all()
	return absf(player.global_position.x - x) <= tolerance


## Ждёт, пока герой свободен: не лежит, не в переходе, не у осколка.
func ready_to_move(limit := 30.0) -> void:
	var time := 0.0
	while (player.frozen or player.lying or rooms._busy) and time < limit:
		await frames(1)
		time += 1.0 / 60.0


func use(node_path: String) -> void:
	var target := rooms.current_room.get_node_or_null(node_path) as Node3D
	if target:
		await walk_to(target.global_position.x, 15.0, 0.6)
	await wait(0.2)
	var room := rooms.current_room
	var is_door := target is RoomDoor
	await tap("interact")
	# Дверь: дождаться новой комнаты.
	if is_door:
		for i in 180:
			if rooms.current_room != room and not rooms._busy:
				break
			await frames(1)
		await ready_to_move()


func climb(seconds: float) -> void:
	Input.action_press("move_up")
	await wait(seconds)
	Input.action_release("move_up")


## Простой боец: подходит, бьёт, перекатывается от замаха, пьёт зелье, когда плохо.
func fight(enemy: Dummy, limit := 30.0, keep_distance := 1.4) -> void:
	var time := 0.0
	while is_instance_valid(enemy) and enemy.state != Dummy.State.DEAD and time < limit and not player.is_dead() and not player.frozen:
		var dx := enemy.global_position.x - player.global_position.x
		var dy := enemy.global_position.y - player.global_position.y
		var dir := signf(dx) if dx != 0.0 else player.facing
		release_all()
		if player.health.current < player.health.max_health * 0.35 and player.flasks > 0 and enemy.state != Dummy.State.WINDUP:
			Input.action_press("move_left" if dir > 0.0 else "move_right")
			await wait(0.35)
			release_all()
			await tap("heal")
			await wait(1.0)
			time += 1.35
			continue
		if enemy.state == Dummy.State.WINDUP and enemy._state_time > enemy.windup_time - 0.28 and absf(dx) < 4.0 and player.stamina >= player.stats.roll_cost:
			Input.action_press("move_left" if dir > 0.0 else "move_right")
			await tap("roll")
			await wait(0.45)
			time += 0.5
			continue
		if absf(dx) > keep_distance or absf(dy) > 1.6:
			Input.action_press("move_right" if dir > 0.0 else "move_left")
		elif player.state == Player.State.MOVE:
			player.facing = dir
			await tap("attack")
			time += 0.07
		await frames(1)
		time += 1.0 / 60.0
	release_all()


func run() -> void:
	GameState.saves_enabled = false
	var main: Node = load("res://main.tscn").instantiate()
	main.get_node("RoomManager").start_room = &"village_hut"
	add_child(main)
	player = main.get_node("Player")
	rooms = main.get_node("RoomManager")
	await frames(2)
	# Отладочные надписи HUD в демо не нужны.
	rooms.hud.age_label.visible = false
	rooms.hud.get_node("Controls").visible = false

	# --- Сон и пробуждение
	await ready_to_move()
	await wait(1.6)
	await use("Objects/DoorToStreet")

	# --- Деревня в огне: палка у тропы, перевоплощение, отползающий человек
	await use("Objects/Stick")
	await wait(1.0)
	await walk_to(-5.0)
	await wait(3.2)
	await walk_to(9.0)
	await wait(3.8)
	await use("Objects/DoorToHouse")
	await wait(1.4)

	# --- Дом: крысы, чердак, летучая мышь
	for rat_name in ["RatA", "RatB"]:
		var rat := rooms.current_room.get_node_or_null("Objects/" + rat_name) as Dummy
		if rat:
			await fight(rat, 20.0, 1.1)
			await wait(0.6)
	await walk_to(7.5)
	await climb(2.2)
	await wait(0.4)
	var bat := rooms.current_room.get_node_or_null("Objects/Bat") as Dummy
	await walk_to(2.0)
	if bat:
		await fight(bat, 20.0, 1.0)
	await wait(0.6)
	await walk_to(7.5, 6.0)
	await wait(1.0)
	await use("Objects/DoorOut")
	await wait(1.4)

	# --- Площадь: оборотень
	await walk_to(-3.0)
	var wolf := rooms.current_room.get_node_or_null("Objects/Werewolf") as Dummy
	await wait(1.2)
	if wolf:
		await fight(wolf, 45.0, 1.6)
	# Не дожал — стоит и принимает удары, пока зверь не услышит зов.
	for i in 1200:
		if GameState.has_flag(&"fire_out") and not player.lying:
			break
		await frames(1)
	await wait(1.5)

	# --- После пожара: осколок, меню отражения
	await use("AfterFire/MirrorShard")
	await wait(3.5)
	rooms.level_menu.close()
	await wait(0.8)
	await use("Objects/DoorToChapel")
	await wait(1.4)

	# --- Двор часовни: кузнец отдаёт меч, часовня, Главное Зеркало
	await use("Objects/Smith")
	await wait(2.6)
	await tap("interact")
	await wait(2.6)
	await use("Objects/Glassblower")
	await wait(2.6)
	await use("Objects/DoorToChapel")
	await wait(1.4)
	await walk_to(0.9)
	await wait(4.0)
	await use("Objects/DoorToYard")
	await wait(1.4)
	await use("Objects/DoorToForest")
	await wait(1.4)

	# --- Край Мёртвого Леса: калитка, фонарь, корень, гнилая доска, сундук
	await walk_to(-9.0)
	await wait(1.0)
	await walk_to(-7.8)
	await climb(2.2)
	await wait(0.5)
	await walk_to(-1.5)
	await wait(0.5)
	await walk_to(1.0, 3.0)
	await wait(1.6)
	await tap("jump")
	await walk_to(3.0, 3.0)
	await use("Objects/PostChest")
	await wait(2.0)
	await use("Objects/DoorToCemetery")

	# --- Кладбище: мародёры
	await walk_to(3.5, 12.0)
	await wait(2.0)
	for robber_name in ["RobberHeavy", "RobberKnife"]:
		var robber := rooms.current_room.get_node_or_null("Objects/" + robber_name) as Dummy
		if robber:
			await fight(robber, 25.0, 1.5)
	await wait(2.0)
	print("demo done")
	get_tree().quit()
