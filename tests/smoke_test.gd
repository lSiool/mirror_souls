extends Node
## Смоук-тест прототипа: симулирует ввод и проходит цикл §12.6.
## Запуск: godot --headless --path . res://tests/smoke_test.tscn  (код выхода 0 — всё прошло).

var main: Node
var player: Player
var rooms: RoomManager
var game_state: Node
var failures := 0


func _ready() -> void:
	run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(t: float) -> void:
	await frames(int(t * 60.0))


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func press(action: String) -> void:
	Input.action_press(action)


func release(action: String) -> void:
	Input.action_release(action)


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(1)


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "roll", "attack", "interact"]:
		Input.action_release(a)


func put(at: Vector3, facing := 1.0) -> void:
	player.teleport(at)
	player.facing = facing
	await frames(3)


func room_node(path: String) -> Node:
	return rooms.current_room.get_node_or_null(path)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	player = main.get_node("Player")
	rooms = main.get_node("RoomManager")
	game_state = GameState
	await seconds(0.5)

	print("== Старт")
	check(absf(player.global_position.x + 17.0) < 0.5, "игрок у PlayerStart (x=%.2f)" % player.global_position.x)
	check(player.is_on_floor(), "игрок стоит на полу")

	print("== Бег и прыжок")
	var x0 := player.global_position.x
	press("move_right")
	await seconds(0.8)
	release("move_right")
	check(player.global_position.x - x0 > 3.0, "бег вправо (dx=%.2f)" % (player.global_position.x - x0))
	await seconds(0.3)
	var y0 := player.global_position.y
	press("jump")
	await seconds(0.3)
	check(player.global_position.y - y0 > 1.0, "прыжок (dy=%.2f)" % (player.global_position.y - y0))
	release("jump")
	await seconds(0.8)

	print("== Перекат")
	await put(Vector3(-12, 0.1, 0))
	await tap("roll")
	check(player.state == Player.State.ROLL, "состояние ROLL")
	check(player.hurtbox.invulnerable, "неуязвимость на перекате")
	await seconds(0.6)
	check(player.state == Player.State.MOVE, "перекат закончился")

	print("== Возраст")
	var speed_17 := player.stats.move_speed
	player.stats.age = 14
	var speed_14 := player.stats.move_speed
	var dmg_14 := player.stats.sword_damage
	player.stats.age = 22
	check(speed_14 > player.stats.move_speed and dmg_14 < player.stats.sword_damage, "14 быстрее, 22 сильнее (%.2f/%.2f, %.1f/%.1f)" % [speed_14, player.stats.move_speed, dmg_14, player.stats.sword_damage])
	player.stats.age = 17
	check(is_equal_approx(speed_17, player.stats.move_speed), "возраст 17 восстановлен")

	print("== Осколок-чекпоинт")
	await put(Vector3(-14, 0.1, 0))
	await seconds(0.2)
	await tap("interact")
	check(String(game_state.checkpoint_path) == "Objects/MirrorShard", "чекпоинт = осколок (%s)" % game_state.checkpoint_path)

	print("== Лазание по стеклянной стене")
	await put(Vector3(-10.4, 0.1, 0), 1.0)
	press("move_right")
	press("move_up")
	await seconds(0.3)
	check(player.state == Player.State.CLIMB, "состояние CLIMB (state=%d)" % player.state)
	for i in 240:
		await frames(1)
		if player.state == Player.State.MOVE and player.is_on_floor():
			break
	release_all()
	await seconds(0.4)
	check(player.global_position.y > 5.8 and player.is_on_floor(), "забрался на платформу (y=%.2f)" % player.global_position.y)

	print("== Скольжение по наклонному стеклу")
	await put(Vector3(-5.0, 6.1, 0), 1.0)
	press("move_right")
	var slid := false
	var max_speed := 0.0
	for i in 90:
		await frames(1)
		if player.state == Player.State.SLIDE:
			slid = true
		max_speed = maxf(max_speed, absf(player.velocity.x))
	release_all()
	check(slid, "было состояние SLIDE")
	check(max_speed > player.stats.move_speed, "импульс со ската выше скорости бега (%.2f)" % max_speed)
	await seconds(1.5)

	print("== Бой с врагом")
	var soldier := room_node("Objects/Soldier") as Dummy
	check(soldier != null, "враг есть в обычной реальности")
	if soldier:
		await put(Vector3(soldier.global_position.x - 1.3, 0.1, 0), 1.0)
		var hp0 := soldier.health.current
		await tap("attack")
		await seconds(0.3)
		check(soldier.health.current < hp0, "удар мечом попал (%.0f → %.0f)" % [hp0, soldier.health.current])
		for i in 8:
			if not is_instance_valid(soldier) or soldier.state == Dummy.State.DEAD:
				break
			player.restore()
			await put(Vector3(soldier.global_position.x - 1.3, 0.1, 0), 1.0)
			await tap("attack")
			await seconds(0.45)
		await seconds(0.8)
		check(not is_instance_valid(soldier), "враг убит и удалён")

	print("== Чистое стекло в нише → сундук")
	player.restore()
	var glass := room_node("Glass/NicheGlass") as GlassSurface
	var chest := room_node("Objects/Chest") as Chest
	check(chest.visible, "сундук виден сквозь чистое стекло")
	await put(Vector3(16.6, 0.1, 0), 1.0)
	await tap("interact")
	check(game_state.currency == 0, "сквозь целое стекло сундук не открыть")
	await tap("attack")
	await seconds(0.4)
	check(glass._broken, "стекло разбито")
	await seconds(0.2)
	await tap("interact")
	await seconds(0.2)
	check(game_state.currency == 50, "сундук открыт, блики = %d" % game_state.currency)

	print("== Красное стекло: удар вниз → шипы → смерть → возрождение")
	await put(Vector3(7, 2.5, 0), 1.0)
	press("move_down")
	await tap("attack")
	release("move_down")
	await seconds(0.6)
	check(room_node("Glass/TrapGlass")._broken, "стекло с прожилками пробито ударом вниз")
	await seconds(0.5)
	check(player.is_dead(), "герой погиб на шипах")
	await seconds(3.0)
	check(not player.is_dead(), "герой возродился")
	check(absf(player.global_position.x + 14.0) < 0.6, "возрождение у осколка (x=%.2f)" % player.global_position.x)
	check(room_node("Objects/Soldier") != null, "комната сброшена: враг снова на месте")
	check(not room_node("Glass/NicheGlass")._broken, "комната сброшена: стекло целое")
	check((room_node("Objects/Chest") as Chest).opened, "открытый сундук остался открытым")

	print("== Зеркало → отражение")
	await seconds(0.5)
	await put(Vector3(-1, 0.1, 0), 1.0)
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.reality == &"mirror", "реальность = отражение")
	check(absf(player.global_position.x - 1.0) < 0.6, "герой у зеркала в отражённой комнате (x=%.2f)" % player.global_position.x)
	check(room_node("Objects/Soldier") == null, "в отражении нет солдата")
	check(room_node("Geometry/MirrorLedge") != null, "в отражении есть уступ")
	var wall := room_node("Glass/ClimbWall") as Node3D
	check(wall and absf(wall.position.x - 9.6) < 0.01, "стена зеркальна по X (x=%.2f)" % (wall.position.x if wall else 0.0))
	var slope := room_node("Glass/Slope") as Node3D
	check(slope and slope.rotation.z > 0.4, "скат развёрнут (rot.z=%.2f)" % (slope.rotation.z if slope else 0.0))
	await seconds(0.5)
	check(player.is_on_floor(), "герой стоит на полу в отражении")

	print("== Засада за мутным стеклом (не смертельна)")
	var ambusher := room_node("Objects/Ambusher") as Dummy
	check(ambusher != null and not ambusher.visible, "засада спит за стеклом")
	player.health.current = 5.0
	await put(Vector3(-16.9, 0.1, 0), -1.0)
	await tap("attack")
	await seconds(0.3)
	var woke := ambusher.visible and ambusher.state != Dummy.State.DORMANT
	check(woke, "засада проснулась (state=%d)" % ambusher.state)
	await seconds(1.5)
	check(not player.is_dead() and player.health.current >= 1.0, "первая засада не убила (hp=%.0f)" % player.health.current)

	print("== Сундук отражения на уступе")
	player.restore()
	await put(Vector3(13.5, 7.7, 0), 1.0)
	await seconds(0.3)
	await tap("interact")
	await seconds(0.2)
	check(game_state.currency == 200, "сундук отражения открыт, блики = %d" % game_state.currency)

	print("== Обратно через зеркало")
	await put(Vector3(1, 0.1, 0), 1.0)
	await seconds(0.3)
	await tap("interact")
	await seconds(1.0)
	check(rooms.reality == &"normal", "вернулись в обычную реальность")
	check(absf(player.global_position.x + 1.0) < 0.6, "герой у зеркала (x=%.2f)" % player.global_position.x)

	print("")
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)
