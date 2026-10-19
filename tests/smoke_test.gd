extends Node
## Смоук-тест прототипа: симулирует ввод и проходит цикл §12.6.
## Запуск: godot --headless --path . res://tests/smoke_test.tscn  (код выхода 0 — всё прошло).

var main: Node
var player: Player
var rooms: RoomManager
var game_state: Node
var failures := 0
var steps_seen: Array[int] = []


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
	release_all()
	player.teleport(at)
	player.facing = facing
	await frames(3)


func room_node(path: String) -> Node:
	return rooms.current_room.get_node_or_null(path)


## Держит направление (и «вверх»), пока герой не залезет и не встанет на опору.
func climb(dir: String) -> void:
	press(dir)
	press("move_up")
	var climbed := false
	for i in 300:
		await frames(1)
		if player.state == Player.State.CLIMB:
			climbed = true
		elif climbed and player.state == Player.State.MOVE and player.is_on_floor():
			break
	release_all()
	await seconds(0.2)


## Бежит в сторону, прыгает у x = edge и тормозит в воздухе над x = stop.
func run_and_jump(dir: String, edge: float, stop: float) -> void:
	press(dir)
	var sign_dir := 1.0 if dir == "move_right" else -1.0
	for i in 120:
		await frames(1)
		if (player.global_position.x - edge) * sign_dir > 0.0:
			break
	press("jump")
	for i in 60:
		await frames(1)
		if (player.global_position.x - stop) * sign_dir > 0.0:
			break
	release(dir)
	press("move_left" if dir == "move_right" else "move_right")
	await seconds(0.15)
	release_all()
	await seconds(0.6)


func start_slide_from_ledge(dir: String, at: Vector3) -> void:
	await put(at, 1.0 if dir == "move_right" else -1.0)
	press(dir)
	for i in 90:
		await frames(1)
		if player.state == Player.State.SLIDE:
			break


func run() -> void:
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	player = main.get_node("Player")
	rooms = main.get_node("RoomManager")
	game_state = GameState
	player.attack_step_started.connect(func(_s: AttackStep, i: int, _t: int) -> void: steps_seen.append(i))
	await seconds(0.5)

	print("== Старт")
	check(absf(player.global_position.x + 21.0) < 0.5, "игрок у PlayerStart (x=%.2f)" % player.global_position.x)
	check(player.is_on_floor(), "игрок стоит на полу")

	print("== Бег и прыжок")
	var x0 := player.global_position.x
	press("move_right")
	await seconds(0.5)
	release("move_right")
	check(player.global_position.x - x0 > 2.0, "бег вправо (dx=%.2f)" % (player.global_position.x - x0))
	await seconds(0.3)
	var y0 := player.global_position.y
	press("jump")
	await seconds(0.3)
	check(player.global_position.y - y0 > 1.0, "прыжок (dy=%.2f)" % (player.global_position.y - y0))
	release("jump")
	await seconds(0.8)

	print("== Кувырок")
	await put(Vector3(-20, 0.1, 0))
	await tap("roll")
	check(player.state == Player.State.ROLL, "состояние ROLL")
	check(player.hurtbox.invulnerable, "неуязвимость на перекате")
	await seconds(0.15)
	check(absf(player.body_mesh.rotation.z) > 0.5, "фигура кувыркается (rot.z=%.2f)" % player.body_mesh.rotation.z)
	await seconds(0.5)
	check(player.state == Player.State.MOVE, "перекат закончился")

	print("== Возраст")
	var speed_17 := player.stats.move_speed
	player.stats.age = 14
	var speed_14 := player.stats.move_speed
	var dmg_14 := player.stats.sword_damage
	player.stats.age = 22
	check(speed_14 > player.stats.move_speed and dmg_14 < player.stats.sword_damage, "14 быстрее, 22 сильнее")
	player.stats.age = 17
	check(is_equal_approx(speed_17, player.stats.move_speed), "возраст 17 восстановлен")

	print("== Осколок-чекпоинт")
	await put(Vector3(-18.5, 0.1, 0))
	await seconds(0.2)
	await tap("interact")
	check(String(game_state.checkpoint_path) == "Objects/MirrorShard", "чекпоинт = осколок (%s)" % game_state.checkpoint_path)

	print("== Башня проходится в обе стороны")
	await put(Vector3(-15.8, 0.1, 0), 1.0)
	await climb("move_right")
	check(player.global_position.y > 5.8 and absf(player.global_position.x + 13.0) < 2.2, "залез на башню слева (%.2f, %.2f)" % [player.global_position.x, player.global_position.y])
	await put(Vector3(-10.2, 0.1, 0), -1.0)
	await climb("move_left")
	check(player.global_position.y > 5.8 and absf(player.global_position.x + 13.0) < 2.2, "залез на башню справа (%.2f, %.2f)" % [player.global_position.x, player.global_position.y])
	press("move_left")
	await seconds(1.2)
	release_all()
	await seconds(0.4)
	check(player.global_position.x < -15.5 and player.global_position.y < 0.5, "спустился с башни обратно к старту (x=%.2f)" % player.global_position.x)

	print("== С башни на уступ")
	await put(Vector3(-12.5, 6.1, 0), 1.0)
	await run_and_jump("move_right", -11.3, -8.0)
	var on_ledge := player.is_on_floor() and absf(player.global_position.y - 7.0) < 0.2
	check(on_ledge, "запрыгнул на уступ (%.2f, %.2f)" % [player.global_position.x, player.global_position.y])

	print("== Скольжение")
	await start_slide_from_ledge("move_right", Vector3(-7, 7.1, 0))
	check(player.state == Player.State.SLIDE, "было состояние SLIDE")
	var max_speed := 0.0
	for i in 60:
		await frames(1)
		max_speed = maxf(max_speed, absf(player.velocity.x))
	release_all()
	check(max_speed > 11.0, "скольжение разогналось (%.2f)" % max_speed)
	await seconds(1.0)

	print("== Удар в скольжении не тормозит")
	await start_slide_from_ledge("move_right", Vector3(-7, 7.1, 0))
	await seconds(0.25)
	var before := player.velocity.length()
	await tap("attack")
	await seconds(0.1)
	check(player.state == Player.State.ATTACK, "удар во время скольжения")
	check(player.velocity.length() >= before * 0.9, "скорость сохранилась (%.2f → %.2f)" % [before, player.velocity.length()])
	release_all()
	await seconds(1.0)

	print("== Кувырок сквозь удар врага")
	var soldier := room_node("Objects/Soldier") as Dummy
	player.restore()
	await put(Vector3(soldier.global_position.x - 1.5, 0.1, 0), 1.0)
	var waited := 0
	while not (soldier.state == Dummy.State.WINDUP and soldier._state_time > soldier.windup_time - 0.12) and waited < 300:
		await frames(1)
		waited += 1
	var hp_before := player.health.current
	press("move_right")
	await tap("roll")
	await seconds(0.6)
	release_all()
	check(soldier.state != Dummy.State.PATROL, "враг атаковал (state=%d)" % soldier.state)
	check(player.health.current == hp_before, "кувырок сквозь удар без урона (hp %.0f → %.0f)" % [hp_before, player.health.current])
	await seconds(0.5)

	print("== Комбо меча: рез → взлёт → выпад")
	player.restore()
	soldier = room_node("Objects/Soldier") as Dummy
	await put(Vector3(soldier.global_position.x - 1.2, 0.1, 0), 1.0)
	steps_seen.clear()
	var hp0 := soldier.health.current
	for i in 3:
		await tap("attack")
		await seconds(0.2)
	await seconds(0.5)
	check(steps_seen == [1, 2, 3], "три стадии подряд (%s)" % str(steps_seen))
	check(player.weapon.combo[2].heavy, "выпад — тяжёлый удар")
	check(not is_instance_valid(soldier) or soldier.health.current < hp0, "комбо попало по врагу")
	await seconds(0.8)

	print("== Чистое стекло в нише → сундук")
	player.restore()
	var glass := room_node("Glass/NicheGlass") as GlassSurface
	var chest := room_node("Objects/Chest") as Chest
	check(chest.visible, "сундук виден сквозь чистое стекло")
	await put(Vector3(19.6, 0.1, 0), 1.0)
	await tap("interact")
	check(game_state.currency == 0, "сквозь целое стекло сундук не открыть")
	await tap("attack")
	await seconds(0.5)
	check(glass._broken, "стекло разбито")
	await tap("interact")
	await seconds(0.2)
	check(game_state.currency == 50, "сундук открыт, блики = %d" % game_state.currency)

	print("== Стекло над ямой: кувырком — успел, шагом — провалился")
	var trap := room_node("Glass/TrapGlass") as GlassSurface
	await put(Vector3(8.55, 0.1, 0), 1.0)
	press("move_right")
	await frames(2)
	await tap("roll")
	await seconds(1.0)
	release_all()
	check(not player.is_dead() and player.global_position.x > 13.0, "кувырком перешёл (x=%.2f)" % player.global_position.x)
	check(trap._broken, "стекло треснуло и разбилось за спиной")
	await seconds(3.0)
	check(not trap._broken, "через ~2.75 с стекло восстановилось")
	await put(Vector3(8.55, 0.1, 0), 1.0)
	press("move_right")
	await seconds(1.2)
	release_all()
	check(player.is_dead(), "шагом не успел — упал на шипы")
	await seconds(3.0)
	check(not player.is_dead(), "герой возродился")
	check(absf(player.global_position.x + 18.5) < 0.6, "возрождение у осколка (x=%.2f)" % player.global_position.x)
	check(room_node("Objects/Soldier") != null, "комната сброшена: враг снова на месте")
	check(not room_node("Glass/NicheGlass")._broken, "комната сброшена: стекло в нише целое")
	check((room_node("Objects/Chest") as Chest).opened, "открытый сундук остался открытым")

	print("== Удар вниз пробивает стекло над ямой")
	await put(Vector3(11, 2.5, 0), 1.0)
	press("move_down")
	await tap("attack")
	release("move_down")
	await seconds(0.6)
	check(room_node("Glass/TrapGlass")._broken, "стекло пробито ударом вниз")
	await seconds(3.5)

	print("== Вниз + прыжок проваливает разбиваемый скат")
	player.restore()
	await start_slide_from_ledge("move_right", Vector3(-7, 7.1, 0))
	await seconds(0.15)
	press("move_down")
	await tap("jump")
	release_all()
	await seconds(0.1)
	check(room_node("Glass/Slope")._broken, "скат разбит")
	check(not player.is_on_floor() and player.state == Player.State.MOVE, "герой падает сквозь скат")
	await seconds(1.0)

	print("== Путь назад: от зеркала к старту")
	player.restore()
	player._iframes = 30.0
	await put(Vector3(14.5, 0.1, 0), -1.0)
	press("move_left")
	for i in 120:
		await frames(1)
		if player.global_position.x < 13.4:
			break
	await tap("roll")
	for i in 240:
		await frames(1)
		if player.global_position.x < -10.0:
			break
	release_all()
	await climb("move_left")
	press("move_left")
	await seconds(1.2)
	release_all()
	await seconds(0.3)
	check(not player.is_dead() and player.global_position.x < -15.5, "вернулся от зеркала к старту (x=%.2f)" % player.global_position.x)
	player._iframes = 0.0

	print("== Зеркало → отражение")
	await put(Vector3(15.5, 0.1, 0), 1.0)
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.reality == &"mirror", "реальность = отражение")
	check(absf(player.global_position.x + 15.5) < 0.6, "герой у зеркала в отражённой комнате (x=%.2f)" % player.global_position.x)
	check(room_node("Objects/Soldier") == null, "в отражении нет солдата под скатом")
	var mirror_soldier := room_node("Objects/MirrorSoldier") as Node3D
	check(mirror_soldier != null and absf(mirror_soldier.global_position.x + 6.0) < 2.0, "отражённый солдат после ската")
	var tower := room_node("Glass/Tower") as Node3D
	check(absf(tower.position.x - 13.0) < 0.01, "башня зеркальна по X (x=%.2f)" % tower.position.x)
	var solid := room_node("Glass/SlopeSolid") as GlassSurface
	check(solid != null and solid.rotation.z > 0.4, "неразбиваемый скат развёрнут")
	check(room_node("Glass/Slope") == null, "разбиваемого ската в отражении нет")

	print("== Неразбиваемый скат держит")
	player._iframes = 30.0
	await start_slide_from_ledge("move_left", Vector3(7, 7.1, 0))
	await seconds(0.15)
	press("move_down")
	await tap("jump")
	release_all()
	await seconds(0.1)
	check(not solid._broken, "вниз + прыжок не разбили скат")
	await seconds(1.5)

	print("== Башня в отражении с обеих сторон")
	await put(Vector3(10.2, 0.1, 0), 1.0)
	await climb("move_right")
	check(player.global_position.y > 5.8, "залез слева (y=%.2f)" % player.global_position.y)
	await put(Vector3(15.8, 0.1, 0), -1.0)
	await climb("move_left")
	check(player.global_position.y > 5.8, "залез справа (y=%.2f)" % player.global_position.y)
	player._iframes = 0.0

	print("== Засада за мутным стеклом (не смертельна)")
	var ambusher := room_node("Objects/Ambusher") as Dummy
	check(ambusher != null and not ambusher.visible, "засада спит за стеклом")
	player.health.current = 5.0
	await put(Vector3(-19.6, 0.1, 0), -1.0)
	await tap("attack")
	await seconds(0.3)
	var woke := ambusher.visible and ambusher.state != Dummy.State.DORMANT
	check(woke, "засада проснулась (state=%d)" % ambusher.state)
	await seconds(1.5)
	check(not player.is_dead() and player.health.current >= 1.0, "первая засада не убила (hp=%.0f)" % player.health.current)

	print("== Сундук отражения на уступе")
	player.restore()
	await put(Vector3(10.5, 8.7, 0), 1.0)
	await seconds(0.3)
	await tap("interact")
	await seconds(0.2)
	check(game_state.currency == 200, "сундук отражения открыт, блики = %d" % game_state.currency)

	print("== Обратно через зеркало")
	await put(Vector3(-15.5, 0.1, 0), 1.0)
	await seconds(0.3)
	await tap("interact")
	await seconds(1.0)
	check(rooms.reality == &"normal", "вернулись в обычную реальность")
	check(absf(player.global_position.x - 15.5) < 0.6, "герой у зеркала (x=%.2f)" % player.global_position.x)

	print("")
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)
