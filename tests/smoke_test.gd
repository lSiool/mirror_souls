extends Node
## Смоук-тест прототипа: симулирует ввод и проходит цикл §12.6.
## Запуск: godot --headless --path . res://tests/smoke_test.tscn  (код выхода 0 — всё прошло).

var main: Node
var player: Player
var rooms: RoomManager
var game_state: Node
var failures := 0
var steps_seen: Array[int] = []
var last_step: AttackStep


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
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "roll", "attack", "interact", "block"]:
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


## Ждёт, пока до удара врага останется меньше `left` секунд замаха.
func wait_windup(enemy: Dummy, left: float) -> void:
	for i in 400:
		if enemy.state == Dummy.State.WINDUP and enemy._state_time > enemy.windup_time - left:
			return
		await frames(1)


## Ждёт, пока удар врага пройдёт (враг перешёл в откат или дальше).
func wait_attack_over(enemy: Dummy) -> void:
	for i in 400:
		if enemy.state in [Dummy.State.RECOVER, Dummy.State.OFF_BALANCE, Dummy.State.CHASE] \
				and enemy._state_time > 0.05:
			return
		await frames(1)


## Ставит героя перед врагом лицом к нему. Враг начинает с чистого листа (патруль),
## чтобы проверка не попала на середину старого замаха.
func face_enemy(enemy: Dummy, distance := 1.5) -> void:
	enemy._set_state(Dummy.State.PATROL)
	enemy._turn_t = -1.0
	enemy.velocity = Vector3.ZERO
	await put(Vector3(enemy.global_position.x + enemy.facing * distance, 0.1, 0), -enemy.facing)


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
	player.attack_step_started.connect(func(st: AttackStep, i: int, _t: int) -> void:
		steps_seen.append(i)
		last_step = st)
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
	check(last_step == player.weapon.slide_attack, "это размашистый удар из скольжения")
	check(player.velocity.length() >= before * 0.9, "скорость сохранилась (%.2f → %.2f)" % [before, player.velocity.length()])
	release_all()
	await seconds(1.0)

	print("== Удар на выходе из скольжения")
	await start_slide_from_ledge("move_right", Vector3(-7, 7.1, 0))
	for i in 120:
		await frames(1)
		if player.state == Player.State.MOVE:
			break
	release_all()
	await frames(3)
	await tap("attack")
	check(last_step == player.weapon.slide_attack, "сразу после ската — тоже размашистый удар")
	await seconds(1.2)

	print("== Удар после кувырка")
	await put(Vector3(-20, 0.1, 0), 1.0)
	await tap("roll")
	await seconds(0.15)
	await tap("attack")
	await seconds(0.4)
	check(last_step == player.weapon.roll_attack, "удар, нажатый в кувырке, — удар после кувырка")
	await seconds(0.6)
	await tap("roll")
	await seconds(0.45)
	await tap("attack")
	check(last_step == player.weapon.roll_attack, "удар сразу после кувырка — удар после кувырка")
	await seconds(0.6)
	await tap("attack")
	check(last_step == player.weapon.combo[0], "без кувырка — обычная первая стадия комбо")
	await seconds(0.6)

	print("== Тела сталкиваются, контакт без урона")
	var soldier := room_node("Objects/Soldier") as Dummy
	soldier.detect_range = 0.0
	player.restore()
	await put(Vector3(soldier.global_position.x - 3.0, 0.1, 0), 1.0)
	var hp_contact := player.health.current
	press("move_right")
	await seconds(1.2)
	release_all()
	var gap := soldier.global_position.x - player.global_position.x
	check(gap > 0.6, "герой упёрся во врага, а не прошёл сквозь (зазор %.2f)" % gap)
	check(player.health.current == hp_contact, "столкновение без урона (hp %.0f)" % player.health.current)

	soldier.global_position = Vector3(0, 0, 0)
	soldier._origin = Vector3.ZERO
	soldier.facing = 1.0
	await put(Vector3(1.3, 0.1, 0), -1.0)
	await seconds(0.8)
	check(soldier.facing > 0.0, "патруль упёрся в героя и не развернулся")
	check(soldier.global_position.x < player.global_position.x, "враг остался перед героем")

	await put(Vector3(soldier.global_position.x, 1.9, 0), 1.0)
	await seconds(1.2)
	var off := absf(player.global_position.x - soldier.global_position.x)
	check(player.is_on_floor() and player.global_position.y < 0.2, "с головы врага соскользнул на пол (y=%.2f)" % player.global_position.y)
	check(off > 0.7, "стоит рядом с врагом, а не на нём (dx=%.2f)" % off)
	soldier.detect_range = 7.0

	print("== Кувырок от удара в последний момент")
	player.restore()
	await put(Vector3(soldier.global_position.x - 1.5, 0.1, 0), 1.0)
	var waited := 0
	while not (soldier.state == Dummy.State.WINDUP and soldier._state_time > soldier.windup_time - 0.06) and waited < 300:
		await frames(1)
		waited += 1
	var hp_before := player.health.current
	press("move_left")
	await tap("roll")
	await seconds(0.6)
	release_all()
	check(soldier.state != Dummy.State.PATROL, "враг атаковал (state=%d)" % soldier.state)
	check(player.health.current == hp_before, "кувырок без урона (hp %.0f → %.0f)" % [hp_before, player.health.current])
	await seconds(0.5)

	print("== Стойкость: одиночный удар не сбивает атакующего врага")
	soldier = room_node("Objects/Soldier") as Dummy
	soldier.health.max_health = 2000.0
	soldier.health.current = 2000.0
	player.restore()
	await face_enemy(soldier)
	player._iframes = 3.0
	await wait_windup(soldier, 0.35)
	await tap("attack")
	await seconds(0.15)
	check(soldier.state in [Dummy.State.WINDUP, Dummy.State.ATTACK, Dummy.State.RECOVER], "враг дотерпел удар (state=%d)" % soldier.state)
	check(soldier.poise < soldier.max_poise, "стойкость снизилась (%.0f)" % soldier.poise)
	player._iframes = 0.0
	await seconds(1.5)

	print("== Комбо меча: рез → взлёт → выпад ломает стойкость")
	soldier.detect_range = 0.0
	soldier.backstab_allowed = false
	soldier.poise = soldier.max_poise
	player.restore()
	await face_enemy(soldier, 1.0)
	steps_seen.clear()
	var hp0 := soldier.health.current
	var staggered := false
	for i in 3:
		await tap("attack")
		for k in 12:
			await frames(1)
			staggered = staggered or soldier.state == Dummy.State.STAGGER
	await seconds(0.3)
	check(steps_seen == [1, 2, 3], "три стадии подряд (%s)" % str(steps_seen))
	check(player.weapon.combo[2].heavy, "выпад — тяжёлый удар")
	check(soldier.health.current < hp0, "комбо попало по врагу")
	check(staggered, "стойкость сломана — стаггер")
	soldier.detect_range = 7.0
	soldier.backstab_allowed = true
	await seconds(1.0)

	print("== Блок")
	player.restore()
	await face_enemy(soldier)
	press("block")
	await wait_windup(soldier, 0.1)
	var hp_block := player.health.current
	await wait_attack_over(soldier)
	check(player.health.current == hp_block, "удар спереди принят на блок без урона")
	check(player.stamina < player.stats.max_stamina, "блок стоил выносливости (%.0f)" % player.stamina)
	release_all()
	await seconds(1.2)

	player.restore()
	await face_enemy(soldier)
	player.facing = -player.facing
	press("block")
	await wait_windup(soldier, 0.1)
	var hp_back := player.health.current
	await wait_attack_over(soldier)
	check(player.health.current < hp_back, "удар в спину при блоке проходит")
	release_all()
	await seconds(1.2)

	print("== Пробитие блока")
	player.restore()
	await face_enemy(soldier)
	press("block")
	await frames(20)
	player.stamina = 0.0
	player._stamina_delay = 10.0
	var broke := false
	var hp_break := player.health.current
	for i in 300:
		await frames(1)
		broke = broke or player.state == Player.State.GUARD_BROKEN
		if broke:
			break
	check(broke, "без выносливости блок пробит")
	check(player.health.current == hp_break, "пробитие само урона не наносит")
	release_all()
	player._stamina_delay = 0.0
	await seconds(1.5)

	print("== Разворот врага не мгновенный")
	player.restore()
	soldier.facing = 1.0
	soldier._set_state(Dummy.State.CHASE)
	await put(Vector3(soldier.global_position.x - 2.5, 0.1, 0), 1.0)
	await seconds(0.2)
	check(soldier.facing > 0.0, "через 0.2 с враг ещё смотрит в старую сторону")
	await seconds(0.4)
	check(soldier.facing < 0.0, "через 0.6 с враг развернулся (turn_time %.1f)" % soldier.turn_time)
	await seconds(1.0)

	print("== Удар в спину")
	player.restore()
	soldier.detect_range = 0.0
	await seconds(0.3)
	await put(Vector3(soldier.global_position.x - soldier.facing * 1.3, 0.1, 0), soldier.facing)
	var hp_bs := soldier.health.current
	await tap("attack")
	check(player.state == Player.State.CRITICAL and last_step == player.weapon.backstab, "удар сзади — удар в спину")
	check(soldier.state == Dummy.State.CRITICAL_HIT, "враг зафиксирован")
	await seconds(0.7)
	var bs_damage := hp_bs - soldier.health.current
	check(absf(bs_damage - player.stats.sword_damage * 3.5) < 1.0, "урон удара в спину ×3.5 (%.1f)" % bs_damage)
	await seconds(1.5)
	soldier.detect_range = 7.0

	print("== Парирование и добивание")
	player.restore()
	await seconds(0.5)
	await face_enemy(soldier)
	await wait_windup(soldier, 0.08)
	var hp_parry := player.health.current
	await tap("block")
	await seconds(0.2)
	check(soldier.state == Dummy.State.OFF_BALANCE, "парирование: враг потерял равновесие (state=%d)" % soldier.state)
	check(player.health.current == hp_parry, "парирование без урона")
	var hp_rip := soldier.health.current
	await tap("attack")
	check(player.state == Player.State.CRITICAL and last_step == player.weapon.riposte, "удар по потерявшему равновесие — добивание")
	check(player.hurtbox.invulnerable, "в добивании герой неуязвим")
	await seconds(0.6)
	var rip_damage := hp_rip - soldier.health.current
	check(absf(rip_damage - player.stats.sword_damage * 3.0) < 1.0, "урон добивания ×3 (%.1f)" % rip_damage)
	await seconds(1.6)

	print("== Позднее парирование — удар проходит")
	player.restore()
	await face_enemy(soldier)
	await wait_windup(soldier, 0.05)
	var hp_late := player.health.current
	# Удар уже прилетел — только теперь жмём блок.
	for i in 30:
		if soldier.state == Dummy.State.ATTACK and soldier._state_time > 0.08:
			break
		await frames(1)
	await tap("block")
	await seconds(0.3)
	check(player.health.current < hp_late, "блок после удара не спас (hp %.0f → %.0f)" % [hp_late, player.health.current])
	await seconds(1.5)

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
	# Проверяем геометрию уровня, а не бой: враг не гонится за героем.
	var guard := room_node("Objects/Soldier") as Dummy
	if guard:
		guard.detect_range = 0.0
	await put(Vector3(14.5, 0.1, 0), -1.0)
	press("move_left")
	for i in 120:
		await frames(1)
		if player.global_position.x < 13.4:
			break
	await tap("roll")
	press("move_left")
	for i in 300:
		await frames(1)
		if player.global_position.x < -10.0:
			break
		# Враг перекрывает дорогу — тела сталкиваются, перепрыгиваем с разбега.
		var blocker := room_node("Objects/Soldier") as Node3D
		if blocker and player.is_on_floor():
			var ahead := player.global_position.x - blocker.global_position.x
			if ahead > 1.8 and ahead < 3.0:
				# Полный прыжок: высота переменная, короткое нажатие даёт низкий прыжок.
				press("jump")
				await seconds(0.3)
				release("jump")
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

	print("== Отражённый солдат удару в спину не поддаётся")
	player.restore()
	var mirror_guard := room_node("Objects/MirrorSoldier") as Dummy
	mirror_guard.detect_range = 0.0
	mirror_guard._set_state(Dummy.State.PATROL)
	await seconds(0.2)
	await put(Vector3(mirror_guard.global_position.x - mirror_guard.facing * 1.3, 0.1, 0), mirror_guard.facing)
	await tap("attack")
	var mg_ok := player.state == Player.State.ATTACK and last_step == player.weapon.combo[0]
	check(mg_ok, "сзади — обычный удар, не удар в спину (state=%d, шаг «%s», враг state=%d)" % [player.state, last_step.display_name if last_step else "-", mirror_guard.state])
	await seconds(0.8)

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
