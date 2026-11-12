extends Node
## Смоук-тест прототипа: симулирует ввод и проходит цикл §12.6.
## Запуск: godot --headless --path . res://tests/smoke_test.tscn  (код выхода 0 — всё прошло).

var main: Node
var player: Player
var rooms: RoomManager
var game_state: Node
var sfx: Node
var failures := 0
var steps_seen: Array[int] = []
var last_step: AttackStep
var last_arrow: Arrow
var last_arrow_speed := 0.0
## Надписи игроку (Events.message) по порядку.
var messages: Array[String] = []
## Правило «оружие всегда в руке» (§6.3): самый большой разрыв кисти и рукояти у врагов
## с руками graybox за весь тест и кто это был.
var weapon_gap := 0.0
var weapon_gap_who := ""


func _ready() -> void:
	run()


func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Dummy
		if enemy == null or enemy.state == Dummy.State.DEAD:
			continue
		var gap := enemy.weapon_gap()
		if gap > weapon_gap:
			weapon_gap = gap
			weapon_gap_who = "%s (%s)" % [enemy.name, Dummy.State.keys()[enemy.state]]


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


## Кнопка паузы событием: меню паузы слушает ввод, а не опрос (Input.action_press его не шлёт).
func pause_key() -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	var up := InputEventAction.new()
	up.action = &"pause"
	Input.parse_input_event(up)
	await frames(2)


## Выбрать ячейку крестовины (клавиша 1–4) и бросить выбранное (G).
func use_slot(slot: int) -> void:
	await tap("quick_%d" % (slot + 1))
	await tap("quick_use")


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(1)


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "roll", "attack", "interact", "block"]:
		Input.action_release(a)


## Прозвучало ли событие с последней очистки истории звуков.
func heard(event: StringName) -> bool:
	return sfx.history.has(event)


func put(at: Vector3, facing := 1.0) -> void:
	release_all()
	player.teleport(at)
	player.facing = facing
	await frames(3)


## Все узлы комнаты, для которых check(node) истинно.
func nodes_where(root: Node, test: Callable) -> Array[Node]:
	var result: Array[Node] = []
	for node in root.find_children("*", "", true, false):
		if test.call(node):
			result.append(node)
	return result


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
## Приём вампира «Мышь» (§6.3): взлёт-телеграф, пике на героя, тьма скрывает превращение,
## мышь пикирует низко сквозь героя, садится и снова человек. Вампир возвращается на место.
func check_vampire_bat(vampire: Vampire) -> void:
	var home := vampire.global_position
	var floor_y := home.y
	await put(Vector3(home.x - 6.0, 0.1, 0.0), 1.0)
	player.restore()
	var hero_x := player.global_position.x
	vampire.start_bat()
	check(vampire.move == Vampire.Move.RISE and vampire.state == Dummy.State.WINDUP, "«Мышь»: взлёт — телеграф, как замах")
	await seconds(vampire.rise_time + 0.1)
	check(vampire.global_position.y > floor_y + 2.5 and vampire.model.spread > 0.9 and vampire.model.eyes_flare > 0.9,
		"вампир взмыл, глаза горят, плащ раскрыт крыльями")
	var dived := false
	for i in 180:
		dived = dived or vampire.move == Vampire.Move.DIVE
		if vampire.move == Vampire.Move.BURST:
			break
		await frames(1)
	check(dived and vampire.move == Vampire.Move.BURST and absf(vampire.global_position.x - hero_x) < 0.8
		and absf(vampire.global_position.y - floor_y) < 0.05, "пике — туда, где стоял герой, удар о землю")
	await seconds(0.2)
	check(vampire.bat.visible and not vampire.model.visible, "из тьмы вылетает огромная мышь, человека нет")
	# Удары по мыши проходят, но приём не сбивают.
	var probe := Hitbox.new()
	rooms.current_room.add_child(probe)
	probe.global_position = vampire.global_position
	probe.damage = 1.0
	probe.poise_damage = 999.0
	var hp_vampire := vampire.health.current
	vampire._on_hurt(probe)
	probe.queue_free()
	check(vampire.health.current < hp_vampire and vampire.move != Vampire.Move.NONE, "удар по мыши ранит, но не сбивает приём")
	var lowest := INF
	var swoop_hit := false
	var aims := 0
	var faced := 0
	for i in 600:
		var hp_frame := player.health.current
		await frames(1)
		if player.health.current < 40.0:
			player.restore()
		elif vampire.move == Vampire.Move.BAT_SWOOP and player.health.current < hp_frame:
			swoop_hit = true
		if vampire.move == Vampire.Move.BAT_SWOOP:
			lowest = minf(lowest, vampire.global_position.y + GiantBat.CENTER - floor_y)
		if vampire.move == Vampire.Move.BAT_AIM and absf(player.global_position.x - vampire.global_position.x) > 0.5:
			aims += 1
			if vampire.bat.facing == signf(player.global_position.x - vampire.global_position.x):
				faced += 1
		if vampire.move == Vampire.Move.NONE:
			break
	check(aims > 0 and faced == aims, "в замахе пике мышь смотрит на героя (%d из %d кадров)" % [faced, aims])
	check(lowest < 0.8, "мышь пикирует низко — через неё прыгают (центр %.2f м над полом)" % lowest)
	check(swoop_hit, "пике мыши достаёт героя, который стоит на месте")
	check(vampire.move == Vampire.Move.NONE and vampire.model.visible and not vampire.bat.visible
		and absf(vampire.global_position.y - floor_y) < 0.05 and vampire.collision_layer != 0,
		"мышь села в облаке тьмы и снова стала человеком")
	check(vampire.state == Dummy.State.RECOVER and vampire.windup_time == vampire._windup_base, "после посадки он открыт, замах когтей прежний")
	vampire.global_position = home
	vampire._bat_wait = 999.0
	player.restore()
	await frames(2)


func face_enemy(enemy: Dummy, distance := 1.5) -> void:
	enemy._set_state(Dummy.State.PATROL)
	enemy._turn_t = -1.0
	enemy.velocity = Vector3.ZERO
	await put(Vector3(enemy.global_position.x + enemy.facing * distance, 0.1, 0), -enemy.facing)


## Выстрел: держать кнопку hold секунд (0 — быстрый), up — целиться вверх.
func shoot(hold: float, up := false) -> void:
	if up:
		press("move_up")
	press("shoot")
	await frames(maxi(int(hold * 60.0), 2))
	release("shoot")
	await frames(2)
	release("move_up")


func start_slide_from_ledge(dir: String, at: Vector3) -> void:
	await put(at, 1.0 if dir == "move_right" else -1.0)
	press(dir)
	for i in 90:
		await frames(1)
		if player.state == Player.State.SLIDE:
			break


## Бот уровня-забега (§8.11): бежит вправо одним из трёх путей «Горящей деревни». Возвращает
## Vector2: наименьший запас после развилки (секунды хода фронта до героя) и время пути, с.
func run_route(route: String) -> Vector2:
	var run := RunLevel.of(rooms.current_room)
	# Края, с которых прыгают: первый и последний мосты, дальше — свои у каждого пути.
	var edges: Array[float] = [28.0, 34.0, 218.0, 224.0]
	match route:
		"road": edges.append_array([67.8, 119.8, 162.8, 196.5])
		"roofs": edges.append_array([65.5, 75.5, 85.5, 97.5, 125.5, 137.5, 165.5, 177.5, 196.5])
		"ravine": edges.append_array([79.5, 117.5])
	# Что надо разбить ударом на бегу: стенка теплицы на крышах, перегородка в овраге.
	var smash: Dictionary = {"roofs": "Objects/Greenhouse", "ravine": "Objects/Barricade"}
	var wall := room_node(smash[route]) as GlassSurface if smash.has(route) else null
	var hatch := room_node("Objects/ForkHatch") as GlassSurface
	var least := INF
	var began := Engine.get_physics_frames()
	var chest_done := false
	press("move_right")
	for i in 60 * 90:
		await frames(1)
		var at := player.global_position
		if player.is_dead() or at.x >= 243.0:
			break
		if run.running and at.x > 58.0:
			least = minf(least, run.time_between(run.front_x, at.x) if at.x > run.front_x else 0.0)
		# Овраг: стеклянный люк на площади пробивается ударом сверху — прыжок, «вниз» + удар.
		if route == "ravine" and not hatch._broken and at.x >= 47.6 and at.x < 49.2 and player.is_on_floor():
			release("move_right")
			press("jump")
			await frames(14)
			release("jump")
			press("move_down")
			await tap("attack")
			release("move_down")
			for k in 60:
				await frames(1)
				if hatch._broken:
					break
			press("move_right")
			continue
		# Преграда на пути: удар на бегу.
		if wall and not wall._broken and wall.global_position.x - at.x < 2.0 and wall.global_position.x - at.x > 0.5 \
				and absf(wall.global_position.y - 1.2 - at.y) < 1.0 and player.state == Player.State.MOVE and player.is_on_floor():
			await tap("attack")
			await frames(8)
			continue
		# Лестницы: на крыши с площади и из оврага к воротам.
		var ladder_top := INF
		if route == "roofs" and at.x >= 54.7 and at.x < 55.6 and at.y < 4.5:
			ladder_top = 4.9
		elif route == "roofs" and at.x >= 170.2 and at.x < 171.1 and at.y > 4.5 and at.y < 7.4:
			ladder_top = 7.9
		elif route == "ravine" and at.x >= 151.2 and at.x < 152.0 and at.y < -3.6:
			ladder_top = -3.2
		elif route == "ravine" and at.x >= 199.2 and at.y < -0.5:
			ladder_top = -0.1
		if ladder_top < INF:
			release("move_right")
			release("jump")
			press("move_up")
			for k in 60 * 6:
				await frames(1)
				if player.global_position.y >= ladder_top and player.is_on_floor():
					break
			release("move_up")
			press("move_right")
			continue
		# Сундук на башенке: остановиться и открыть.
		if route == "roofs" and not chest_done and at.x >= 174.6 and at.y > 7.5 and player.is_on_floor():
			chest_done = true
			release("move_right")
			await frames(4)
			await tap("interact")
			press("move_right")
			continue
		if route == "road" and at.x > 148.6 and at.x < 151.4 and not game_state.has_flag(&"run_village_road"):
			await tap("interact")
		# Враг на пути и на том же этаже: громилу в погребе — убить, остальных — перекатом.
		var foe: Dummy = null
		for node in get_tree().get_nodes_in_group("enemy"):
			var each := node as Dummy
			if each == null or each.state == Dummy.State.DEAD:
				continue
			var gap := each.global_position.x - at.x
			if gap > 0.0 and gap < 2.6 and absf(each.global_position.y - at.y) < 1.6:
				foe = each
		if foe and foe.name == "Brute":
			release("move_right")
			for k in 60 * 12:
				if not is_instance_valid(foe) or foe.state == Dummy.State.DEAD or player.is_dead():
					break
				player.facing = signf(foe.global_position.x - player.global_position.x)
				await tap("attack")
				await frames(6)
			press("move_right")
			continue
		if foe and player.state == Player.State.MOVE and player.is_on_floor():
			await tap("roll")
			press("move_right")
			continue
		var jump := false
		if player.is_on_floor():
			for edge in edges:
				if at.x >= edge and at.x < edge + 0.7:
					jump = true
			if absf(player.velocity.x) < 1.0 and at.x > 10.0:
				jump = true
		if jump:
			press("jump")
		elif player.velocity.y <= 0.0:
			release("jump")
	release_all()
	if is_instance_valid(wall):
		check(wall._broken, "путь «%s»: преграда разбита ударом на бегу (%s)" % [route, wall.name])
	if is_instance_valid(hatch):
		check(hatch._broken == (route == "ravine"), "путь «%s»: стеклянный люк %s" % [route, "пробит ударом сверху" if route == "ravine" else "цел — по нему пробежали"])
	return Vector2(least, (Engine.get_physics_frames() - began) / 60.0)


## Бот нестабильного отражения (§8.11): бежит (зажат перекат), идёт на таран (зажат блок),
## прыгает у края глыбы и через низкий обломок. Возвращает, сколько секунд бежал.
func run_reflection() -> float:
	var began := Engine.get_physics_frames()
	press("move_right")
	press("roll")
	await frames(20)
	press("block")
	for i in 60 * 70:
		await frames(1)
		var at := player.global_position
		if i % 15 == 0:
			var run_dbg := RunLevel.of(rooms.current_room)
			print("DBG t=%.2f x=%.1f y=%.2f vx=%.1f floor=%s hp=%.0f front=%.1f" % [i / 60.0, at.x, at.y, player.velocity.x, player.is_on_floor(), player.health.current, run_dbg.front_x if run_dbg else 0.0])
		if player.is_dead() or rooms.current_room_id != &"reflection_run":
			break
		var jump := false
		if player.is_on_floor():
			# Край глыбы под ногами близко — прыжок.
			for node in get_tree().get_nodes_in_group(&"flying_shard"):
				var shard := node as FlyingShard
				var right_edge := shard.global_position.x + shard.size.x * 0.5
				var top := shard.global_position.y + shard.size.y * 0.5
				if absf(top - at.y) < 0.5 and at.x > right_edge - 1.0 and at.x < right_edge and absf(shard.global_position.x - at.x) < shard.size.x * 0.5 + 0.5:
					jump = true
			# Низкий обломок впереди — прыжок.
			for node in get_tree().get_nodes_in_group(&"glass_meteor"):
				var rock := node as GlassMeteor
				var dx := rock.global_position.x - at.x
				if rock.flying and dx > 0.0 and dx < 5.5 and rock.global_position.y - at.y < 1.8:
					jump = true
		if jump:
			press("jump")
		elif player.velocity.y <= 0.0:
			release("jump")
	release_all()
	return (Engine.get_physics_frames() - began) / 60.0


func run() -> void:
	main = load("res://main.tscn").instantiate()
	# Тест идёт в комнате-прототипе, с мечом и луком и без записи на диск.
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	GameState.set_flag(&"has_bow")
	main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	player = main.get_node("Player")
	rooms = main.get_node("RoomManager")
	game_state = GameState
	sfx = Sfx
	player.attack_step_started.connect(func(st: AttackStep, i: int, _t: int) -> void:
		steps_seen.append(i)
		last_step = st)
	Events.message.connect(func(text: String) -> void: messages.append(text))
	# Окно находки не перехватывает «взаимодействие» тестов; своя проверка — у бруска.
	rooms.hud.popup.blocks_interact = false
	player.arrow_fired.connect(func(a: Arrow) -> void:
		last_arrow = a
		last_arrow_speed = a.velocity.length())
	await seconds(0.5)

	print("== Сюжетный забег: нестабильное отражение (§8.11)")
	var refl_checkpoint := [game_state.checkpoint_room, game_state.checkpoint_reality, game_state.checkpoint_path]
	var refl_items: Dictionary = game_state.items.duplicate()
	var refl_echoes: int = game_state.echoes
	await rooms.travel(&"room_001", ^"Spawns/PlayerStart")
	player.restore()
	var gate_in := room_node("Objects/GateToReflection") as RoomDoor
	# Влетел в стеклянную преграду бегом — пробил её собой и вылетел в отражение.
	await put(gate_in.global_position + Vector3(-6.0, 0.1, 0.0), 1.0)
	press("move_right")
	press("roll")
	for i in 240:
		await frames(1)
		if rooms.current_room_id == &"reflection_run" and not rooms._busy:
			break
	release_all()
	check(rooms.current_room_id == &"reflection_run", "бегом сквозь стеклянную преграду — в отражение")
	check(player.velocity.x > 4.0, "вылетел из стекла вперёд (%.1f м/с)" % player.velocity.x)
	var refl := RunLevel.of(rooms.current_room)
	check(refl and refl.free_run and player.free_run and refl.shatter_wall, "в отражении бег бесплатный, сзади схлопывается")
	check(refl.speed_at(0.0) > player.stats.move_speed and refl.speed_at(0.0) < player.stats.move_speed * Player.SPRINT_SPEED,
		"шагом не уйти, бегом — можно (фронт %.1f м/с)" % refl.speed_at(0.0))
	var pane0 := room_node("Objects/Pane0") as GlassSurface
	check(pane0.is_thin() and pane0.is_in_group(&"glass_thin"), "пластины в отражении — тонкое стекло под таран")
	# Не успел: упал — к последнему осколку, не к следующему; отражение не закрыто, пройти заново.
	await put(Vector3(30.0, -20.0, 0.0), 1.0)
	for i in 240:
		await frames(1)
		if player.is_dead():
			break
	await seconds(RoomManager.DEATH_HOLD + 1.6)
	check(rooms.current_room_id == refl_checkpoint[0] and not game_state.has_flag(&"reflection_done"),
		"сорвался в пустоту — очнулся у последнего осколка, отражение не пройдено")
	game_state.hero_echo = {}
	game_state.echoes = refl_echoes
	# Бот бежит отражение целиком.
	await rooms.travel(&"reflection_run", ^"Spawns/PlayerStart")
	player.restore()
	await seconds(0.3)
	var refl_time := await run_reflection()
	check(rooms.current_room_id == &"room_001" and game_state.has_flag(&"reflection_done"),
		"бот пробежал отражение за %.1f с и выскочил сквозь стекло (сейчас %s, x=%.1f)" % [refl_time, rooms.current_room_id, player.global_position.x])
	check(game_state.items == refl_items and game_state.echoes == refl_echoes, "в отражении ни предметов, ни отзвуков")
	# Мир — как был.
	game_state.set_flag(&"reflection_done", false)
	game_state.set_checkpoint(refl_checkpoint[0], refl_checkpoint[1], refl_checkpoint[2])
	player.restore()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)
