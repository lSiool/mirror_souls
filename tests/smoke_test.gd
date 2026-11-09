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

	print("== Звук: банки")
	var chosen: Array[StringName] = [&"player_step_floor", &"player_land", &"player_roll", &"player_knee",
		&"player_body_fall", &"death_sting", &"sword_block", &"sword_parry", &"critical_pierce",
		&"critical_release", &"glass_break", &"sword_hit_glass", &"arrow_ricochet_glass", &"enemy_hurt",
		&"arrow_hit_wood", &"chest_open", &"chest_loot", &"glass_glint", &"glass_glint_trap",
		&"weapon_drop", &"glass_crack", &"enemy_death", &"sword_hit", &"sword_hit_finisher", &"player_jump",
		&"player_jump_voice", &"player_hurt", &"sword_swing", &"sword_swing_thrust", &"bow_draw",
		&"enemy_hurt_voice", &"enemy_death_voice", &"bow_release", &"player_fall_hurt"]
	var short: Array[String] = []
	for event in chosen:
		if sfx.variants(event) < 2:
			short.append("%s=%d" % [event, sfx.variants(event)])
	check(short.is_empty(), "банки выбранных звуков на месте (%d событий) %s" % [chosen.size(), ", ".join(short)])
	for event: StringName in sfx.EVENTS:
		if sfx.variants(event) == 1:
			check(false, "%s: один вариант — нужен банк для чередования" % event)
	var ring: AudioStreamWAV = ModalSynth.render(ModalMaterial.glass(), 0.7, 0.3, 1.0, 7)
	var knock: AudioStreamWAV = ModalSynth.render(ModalMaterial.wood(), 0.7, 0.3, 1.0, 7)
	check(ring.get_length() > knock.get_length() and knock.get_length() > 0.05, \
		"синтез: стекло звенит дольше дерева (%.2f с > %.2f с)" % [ring.get_length(), knock.get_length()])

	print("== Старт")
	check(absf(player.global_position.x + 21.0) < 0.5, "игрок у PlayerStart (x=%.2f)" % player.global_position.x)
	check(player.is_on_floor(), "игрок стоит на полу")

	print("== Бег и прыжок")
	var x0 := player.global_position.x
	sfx.history.clear()
	press("move_right")
	await seconds(0.5)
	release("move_right")
	check(player.global_position.x - x0 > 2.0, "бег вправо (dx=%.2f)" % (player.global_position.x - x0))
	check(sfx.history.count(&"player_step_floor") >= 2, "шаги на бегу (%d)" % sfx.history.count(&"player_step_floor"))
	await seconds(0.3)
	sfx.history.clear()
	await seconds(0.5)
	check(not heard(&"player_step_floor"), "стоя — шагов нет")
	var y0 := player.global_position.y
	press("jump")
	await seconds(0.3)
	check(player.global_position.y - y0 > 1.0, "прыжок (dy=%.2f)" % (player.global_position.y - y0))
	check(heard(&"player_jump") and not heard(&"player_jump_voice"), "обычный прыжок — толчок без голоса")
	player.stamina = player.stats.max_stamina * 0.2
	check(player.jump_is_effort(), "выдохся — прыжок с усилием, с голосом")
	player.stamina = player.stats.max_stamina
	release("jump")
	await seconds(0.8)
	check(heard(&"player_land"), "звук приземления")
	check(player.health.current == player.stats.max_health, "обычный прыжок — без урона от падения")

	print("== Падение с высоты")
	var hp_full := player.health.current
	player._land_from(player.stats.fall_safe_height - 0.5)
	check(player.health.current == hp_full, "невысоко — без урона")
	sfx.history.clear()
	player._land_from(lerpf(player.stats.fall_safe_height, player.stats.fall_lethal_height, 0.5))
	var lost := hp_full - player.health.current
	var expected := player.stats.max_health * pow(0.5, player.stats.fall_damage_power)
	check(absf(lost - expected) < 0.5 and heard(&"player_fall_hurt"), \
		"полпути до смертельной высоты — %.0f здоровья и голос (%.1f)" % [expected, lost])
	player.health.heal_full()
	await seconds(0.3)

	print("== Музыка и гул зеркала")
	var manager := get_tree().root.find_children("*", "RoomManager", true, false)[0] as RoomManager
	check(manager.music != null and manager.music.playing, "музыка комнаты играет")
	var portals := get_tree().root.find_children("*", "MirrorPortal", true, false)
	check(not portals.is_empty() and portals.all(func(p: MirrorPortal) -> bool: return p.hum and p.hum.playing),
		"зеркала гудят (%d)" % portals.size())

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

	print("== Лечебное зелье")
	player.restore()
	var hp_max := player.stats.max_health
	check(player.flasks == 1 and player.max_flasks() == 1, "в начале игры один глоток")
	player.health.take_damage(50.0)
	await tap("heal")
	check(player.state == Player.State.DRINK and player.flasks == 0, "пьёт зелье, глотков 0")
	await seconds(1.0)
	check(absf(player.health.current - (hp_max - 50.0 + hp_max * 0.6)) < 0.5, "глоток лечит 60 %% (здоровье %.0f)" % player.health.current)
	await tap("heal")
	check(player.state != Player.State.DRINK, "зелье кончилось — пить нечего")
	game_state.add_item(&"flask_vessel")
	game_state.add_item(&"flask_potency")
	player.restore()
	check(player.flasks == 2, "сосуд из тайника: глотков два")
	player.health.take_damage(60.0)
	await tap("heal")
	await seconds(1.0)
	check(absf(player.health.current - minf(hp_max - 60.0 + hp_max * 0.75, hp_max)) < 0.5, "Травница улучшила зелье: 75 %% (здоровье %.0f)" % player.health.current)
	game_state.take_item(&"flask_vessel")
	game_state.take_item(&"flask_potency")
	player.restore()

	print("== Осколок-чекпоинт")
	await put(Vector3(-18.5, 0.1, 0))
	await seconds(0.2)
	var room_before := rooms.current_room
	player.health.take_damage(30.0)
	await tap("interact")
	check(String(game_state.checkpoint_path) == "Objects/MirrorShard", "чекпоинт = осколок (%s)" % game_state.checkpoint_path)
	await seconds(1.2)
	check(rooms.current_room != room_before and player.health.current == player.stats.max_health,
		"отдых у осколка: комната пересоздана, здоровье полное")
	check(rooms.level_menu.is_open and player.frozen, "после отдыха открыто меню у осколка, герой стоит")
	var shard_menu := rooms.level_menu
	check(shard_menu._page == LevelMenu.Page.ROOT and shard_menu._pages[LevelMenu.Page.ROOT].visible, "меню осколка открывается списком")
	shard_menu.show_page(LevelMenu.Page.LEVEL)
	check(shard_menu._pages[LevelMenu.Page.LEVEL].visible and shard_menu._title.text == "Поднять уровень", "пункт «Поднять уровень» — свой экран")
	shard_menu.back()
	check(shard_menu.is_open and shard_menu._page == LevelMenu.Page.ROOT, "«Назад» возвращает к списку")
	for page in [LevelMenu.Page.FACETS, LevelMenu.Page.WEAPON, LevelMenu.Page.ITEMS]:
		shard_menu.show_page(page)
	check(shard_menu._item_grid.get_child_count() >= 1, "в «Предметах» есть хотя бы зелье")
	shard_menu.back()
	shard_menu.back()
	check(not shard_menu.is_open, "«Назад» в списке — отойти от осколка")
	rooms.level_menu.close()
	check(not player.frozen, "отошёл от осколка — герой свободен")
	room_before = rooms.current_room
	await tap("interact")
	await seconds(1.2)
	check(rooms.current_room != room_before, "у осколка можно отдыхать снова")

	print("== Уровень у осколка")
	var stats := player.stats
	var menu := rooms.level_menu
	var cost := stats.level_cost()
	var age_before := stats.current_age
	var speed_before := stats.move_speed
	var hud: Hud = rooms.hud
	var hp_bar_before := hud.health_bar.size.x
	var hp_frame_before := hud.health_frame.size.x
	game_state.add_echoes(cost - 1 - game_state.echoes)
	menu._refresh()
	menu.choose(PlayerStats.Param.VIGOR)
	check(menu.pending_total() == 0 and menu._confirm.disabled, "не хватает отзвуков — выбрать нельзя")
	game_state.add_echoes(1)
	menu._refresh()
	check(menu._confirm.disabled, "ничего не выбрано — «Подтвердить» не горит")
	menu.choose(PlayerStats.Param.VIGOR)
	check(not menu._confirm.disabled and stats.level == 0 and game_state.echoes == cost, "выбрано — «Подтвердить» горит, уровень ещё не куплен")
	menu.confirm()
	check(menu._dialog.visible, "окно «Повысить уровень?»")
	await menu.answer(false)
	check(stats.level == 0 and game_state.echoes == cost and menu.pending_total() == 1, "«Нет» ничего не меняет, выбор остался")
	menu.confirm()
	await menu.answer(true)
	check(stats.level == 1 and game_state.echoes == 0 and menu.pending_total() == 0, "«Да»: уровень куплен за %d отзвуков" % cost)
	check(is_equal_approx(stats.max_health, stats.base_health + 6.0), "первое очко здоровья: +6 (%.0f)" % stats.max_health)
	check(hud.health_bar.size.x > hp_bar_before and hud.health_frame.size.x > hp_frame_before,
		"полоса здоровья и рама длиннее (%.0f → %.0f)" % [hp_bar_before, hud.health_bar.size.x])
	var opening := hud.health_frame.opening_rect()
	check(is_equal_approx(hud.health_bar.position.x, hud.health_frame.position.x + opening.x)
		and is_equal_approx(hud.health_bar.size.x, opening.y), "полоса лежит в проёме рамы целиком, до наконечника")
	check(is_equal_approx(stats.current_age, age_before + 0.25), "герой повзрослел на четверть года (%.2f)" % stats.current_age)
	check(stats.max_health > stats.base_health and is_equal_approx(player.health.max_health, stats.max_health),
		"здоровье выросло (%.1f)" % stats.max_health)
	check(stats.move_speed < speed_before, "годы забрали скорость (%.3f → %.3f)" % [speed_before, stats.move_speed])
	game_state.add_item(&"clear_glass")
	menu.use_clear_glass()
	check(stats.unspent == 1 and is_equal_approx(stats.max_health, stats.base_health)
		and is_equal_approx(stats.current_age, age_before + 0.25) and game_state.item_count(&"clear_glass") == 0,
		"чистое стекло: очко свободно, возраст тот же")
	menu.choose(PlayerStats.Param.STRENGTH)
	menu.confirm()
	await menu.answer(true)
	check(stats.unspent == 0 and stats.level == 1 and stats.points_in(PlayerStats.Param.STRENGTH) == 1,
		"свободное очко вложено без отзвуков и без новых лет")
	menu.close()
	stats.reset_progress()
	stats.level = 120
	var full_age := stats.current_age
	stats.level = 500
	check(is_equal_approx(full_age, stats.age + 30.0) and is_equal_approx(stats.current_age, full_age),
		"за 120 уровней — плюс 30 лет, дальше годы не прибавляются")
	check(stats.move_speed >= stats.move_speed_young * stats.move_speed_limit - 0.001
		and stats.jump_velocity >= stats.jump_velocity_young * stats.jump_velocity_limit - 0.001
		and stats.sword_damage <= stats.sword_damage_young * stats.sword_damage_limit + 0.001,
		"тело не выходит за планки (скорость %.2f, прыжок %.2f, урон %.1f)" % [stats.move_speed, stats.jump_velocity, stats.sword_damage])
	stats.points[PlayerStats.Param.VIGOR] = 15
	check(is_equal_approx(stats.health_bonus(15), 90.0) and is_equal_approx(stats.health_bonus(30), 150.0) \
		and is_equal_approx(stats.health_bonus(50), 190.0), "здоровье ступенями: +90 к 15 очкам, +150 к 30, +190 к 50")
	check(stats.health_bonus(51) - stats.health_bonus(50) < stats.health_bonus(1) * 0.2, "на высоких уровнях прибавка мала")
	stats.points[PlayerStats.Param.VIGOR] = 2000
	check(stats.max_health <= stats.base_health + stats.health_bonus_cap, "здоровье не выше потолка (%.0f)" % stats.max_health)
	stats.reset_progress()

	print("== Восемь характеристик и скалирование")
	check(PlayerStats.PARAM_ORDER.size() == 8 and PlayerStats.Param.ENDURANCE == 1 and PlayerStats.Param.DEXTERITY == 3
		and PlayerStats.Param.MEMORY == 7, "восемь характеристик; первые четыре — прежние ключи сейва, Память — в конце")
	var sword_plain := player.weapon_damage(WeaponData.by_id(&"sword"), 0)
	var hammer_plain := player.weapon_damage(WeaponData.by_id(&"candlestick"), 0)
	stats.points[PlayerStats.Param.STRENGTH] = 20
	var sword_gain := player.weapon_damage(WeaponData.by_id(&"sword"), 0) / sword_plain
	var hammer_gain := player.weapon_damage(WeaponData.by_id(&"candlestick"), 0) / hammer_plain
	check(sword_gain > 1.0 and hammer_gain > sword_gain, "сила: подсвечник (C) растёт сильнее меча (D): ×%.2f против ×%.2f" % [hammer_gain, sword_gain])
	stats.points[PlayerStats.Param.DEXTERITY] = 20
	check(player.weapon_damage(WeaponData.by_id(&"sword"), 0) / sword_plain > sword_gain and stats.critical_mult > 1.0,
		"ловкость: меч (C) и добивания сильнее")
	var load_before := stats.equip_load
	stats.points[PlayerStats.Param.VITALITY] = 10
	check(stats.equip_load > load_before and stats.defense(&"physical") > stats.defense(&"glass"), "крепость: больше вес и защита")
	stats.points[PlayerStats.Param.LUCK] = 10
	check(stats.discovery > 100.0 and stats.bleed_mult > 1.0, "удача: находчивость и кровотечение")
	check(stats.mobility_at(30.0) > stats.mobility_at(14.0) and stats.mobility_at(45.0) > stats.mobility_at(55.0)
		and stats.mobility_at(90.0) >= stats.mobility_floor, "подвижность: растёт до 45, потом падает до планки")
	stats.reset_progress()
	player.restore()
	await put(Vector3(-20.0, 0.1, 0))
	var light_hit := Hitbox.new()
	rooms.current_room.add_child(light_hit)
	light_hit.damage = 5.0
	light_hit.poise_damage = 15.0
	player._on_hurt(light_hit)
	check(player.state == Player.State.HURT, "без стойкости удар сбивает героя")
	await seconds(0.9)
	stats.points[PlayerStats.Param.ENDURANCE] = 20
	player._iframes = 0.0
	player._on_hurt(light_hit)
	check(player.state != Player.State.HURT and player.health.current < player.health.max_health, "стойкость 20: удар ранит, но не сбивает")
	light_hit.heavy = true
	player._iframes = 0.0
	player._on_hurt(light_hit)
	check(player.state == Player.State.HURT, "тяжёлый удар сбивает всегда")
	light_hit.queue_free()
	stats.reset_progress()
	player.restore()
	await seconds(0.9)
	await seconds(0.5)

	print("== Кувырок и выносливость")
	await put(Vector3(-20.0, 0.1, 0))
	player._combat_t = 99.0
	player.stamina = player.stats.max_stamina
	check(not player.in_combat(), "рядом никто не дерётся — вне боя")
	await tap("roll")
	await seconds(0.6)
	check(is_equal_approx(player.stamina, player.stats.max_stamina), "вне боя кувырок не тратит выносливость")
	player._combat_t = 0.0
	player.stamina = player.stats.max_stamina
	await tap("roll")
	await frames(3)
	check(player.in_combat() and player.stamina <= player.stats.max_stamina - player.stats.roll_cost + 0.5, "в бою кувырок тратит выносливость")
	await seconds(0.6)
	player._combat_t = 0.0
	player.stamina = player.stats.roll_cost * 0.5
	await tap("roll")
	await frames(2)
	check(player.state != Player.State.ROLL, "в бою без выносливости кувырка нет")
	player._combat_t = 99.0
	player.stamina = player.stats.max_stamina
	await seconds(0.3)

	print("== Кровотечение героя")
	player.restore()
	var hp_wound := player.health.current
	player.start_wound(4.0, 4.0)
	await seconds(1.0)
	var lost_wound := hp_wound - player.health.current
	check(player.wound_t > 0.0 and lost_wound > 0.6 and lost_wound < 1.6, "рана кровоточит: −%.1f за секунду" % lost_wound)
	await seconds(3.4)
	check(player.wound_t <= 0.0, "кровь остановилась")
	player.health.current = 3.0
	player.start_wound(50.0, 1.0, true)
	await seconds(1.3)
	check(not player.is_dead() and player.health.current >= 1.0, "рана от оборотня не убивает (%.1f)" % player.health.current)
	var calm := Hitbox.new()
	rooms.current_room.add_child(calm)
	calm.damage = 1.0
	player.restore()
	player._on_hurt(calm)
	check(player.wound_t <= 0.0, "удар без шанса раны — крови нет")
	calm.wound_chance = 1.0
	calm.wound_total = 4.0
	player._on_hurt(calm)
	check(player.wound_t > 0.0, "удар с шансом раны — кровь")
	calm.queue_free()
	player.wound_t = 0.0
	player.restore()
	await seconds(0.8)

	print("== Пауза между кувырками")
	player.restore()
	await put(Vector3(-16.0, 0.1, 0), 1.0)
	await seconds(0.3)
	await tap("roll")
	await seconds(stats.roll_duration + 0.03)
	check(player.state != Player.State.ROLL and player.roll_cooling(), "кувырок кончился — пауза перед следующим")
	await tap("roll")
	check(player.state != Player.State.ROLL, "в паузе новый кувырок не начинается")
	await seconds(stats.roll_cooldown + 0.05)
	check(player.state == Player.State.ROLL, "нажатие подождало паузу — кувырок")
	await seconds(stats.roll_duration + 0.3)
	# Кувырки подряд: всегда есть окно уязвимости длиннее самого короткого удара врага (0,16 с).
	var open_t := 0.0
	var open_best := 0.0
	press("roll")
	for i in 150:
		await frames(1)
		if player.hurtbox.invulnerable:
			open_t = 0.0
		else:
			open_t += 1.0 / Engine.physics_ticks_per_second
			open_best = maxf(open_best, open_t)
		if i % 6 == 0:
			release("roll")
			await frames(1)
			press("roll")
	release("roll")
	check(open_best >= 0.18, "кувырки подряд: щель уязвимости %.2f с — удар найдёт окно" % open_best)
	await seconds(0.5)

	print("== Грани")
	var youth := Facet.by_id(&"facet_youth")
	var experience := Facet.by_id(&"facet_experience")
	var blood := Facet.by_id(&"facet_blood")
	check(youth != null and experience != null and blood != null and Facet.catalog().size() >= 8, "грани загружены (%d)" % Facet.catalog().size())
	var plain_speed := stats.move_speed
	stats.toggle_facet(youth, 3)
	check(stats.move_speed > plain_speed and stats.facet_slots_used() == 2, "Лёгкость юности: быстрее (%.2f → %.2f)" % [plain_speed, stats.move_speed])
	var young_bonus := stats.move_speed / plain_speed
	check(not stats.toggle_facet(experience, 3), "на вторую грань в 2 слота места нет")
	stats.level = 92
	check(stats.move_speed / stats.speed_at(stats.current_age) < young_bonus, "с годами юность слабеет")
	stats.level = 0
	stats.toggle_facet(youth, 3)
	stats.toggle_facet(experience, 3)
	var young_power := stats.facet_mult(&"damage")
	stats.level = 92
	check(stats.facet_mult(&"damage") > young_power, "с годами опыт растёт (x%.2f → x%.2f)" % [young_power, stats.facet_mult(&"damage")])
	stats.reset_progress()
	stats.toggle_facet(blood, 3)
	check(stats.max_health < stats.base_health and is_equal_approx(player.health.max_health, stats.max_health), "сильная грань с минусом: здоровья меньше (%.0f)" % stats.max_health)
	stats.reset_progress()
	check(is_equal_approx(player.health.max_health, stats.base_health), "сняли — здоровье как было")
	player.restore()

	print("== Мастерство оружия")
	game_state.mastery.clear()
	check(not player.can_parry() and player.weapon.combo_at(game_state.mastery_step(&"sword")).size() == 3,
		"новичок: блок без парирования, серия из трёх")
	await tap("block")
	check(player._parry_t == 0.0, "блок нажат — окна парирования нет")
	var kills := 0
	while game_state.mastery_step(&"sword") < 1 and kills < 200:
		game_state.add_mastery(&"sword", Dummy.MASTERY_POINTS[Dummy.Rank.COMMON])
		kills += 1
	check(kills == 20 and player.can_parry() and player.weapon.combo_at(1).size() == 3, "первая ступень за 20 врагов: парирование (%d)" % kills)
	while game_state.mastery_step(&"sword") < 2 and kills < 200:
		game_state.add_mastery(&"sword", 1.0)
		kills += 1
	check(kills == 50 and player.weapon.combo_at(2).size() == 4, "вторая — 50 врагов всего: четвёртый удар (%d)" % kills)
	check(player.weapon.step_names[0] == "Парирование", "в меню первая ступень — парирование")
	game_state.mastery.clear()
	check(Dummy.MASTERY_POINTS[Dummy.Rank.BOSS] == 5.0 and Dummy.MASTERY_POINTS[Dummy.Rank.MINIBOSS] == 2.0, "босс даёт 5 очков, мини-босс 2")
	game_state.add_mastery(&"sword", Dummy.MASTERY_POINTS[Dummy.Rank.BOSS])
	check(is_equal_approx(game_state.mastery_xp(&"sword"), 5.0), "босс засчитан целиком, без потолка")
	game_state.mastery.clear()
	var spearman := room_node("Objects/Soldier") as Dummy
	spearman.weapon_type = &"spear"
	spearman.last_weapon = &"bow"
	spearman.health.take_damage(INF)
	await frames(2)
	check(is_equal_approx(game_state.mastery_xp(&"bow"), 1.0) and is_equal_approx(game_state.mastery_xp(&"spear"), 1.0 / 3.0),
		"убит копейщик стрелой: лук +1, копьё +⅓ (%.2f, %.2f)" % [game_state.mastery_xp(&"bow"), game_state.mastery_xp(&"spear")])
	await seconds(1.8)
	rooms._rest()
	await seconds(1.0)
	game_state.mastery.clear()
	game_state.mastery[&"sword"] = 1000.0
	check(player.can_parry() and player.weapon.combo_at(5).size() == 4, "мастер: парирование, серия из четырёх")

	print("== Четвёртый удар и кровотечение")
	var bleeder := room_node("Objects/Soldier") as Dummy
	bleeder.health.max_health = 300.0
	bleeder.health.heal_full()
	bleeder.detect_range = 0.0
	bleeder.patrol_speed = 0.0
	player.restore()
	await face_enemy(bleeder, 1.2)
	steps_seen.clear()
	for i in 4:
		await tap("attack")
		# Следующий удар — как только открылось окно продолжения серии.
		while player.state == Player.State.ATTACK and player._state_time < player._step.chain_from:
			await frames(1)
	await seconds(0.5)
	check(steps_seen == [1, 2, 3, 4], "серия мастера: четыре удара подряд (%s)" % str(steps_seen))
	check(bleeder.bleed > 0.0 or bleeder.health.current < 300.0 * 0.8, "удары мастера копят кровотечение (%.0f)" % bleeder.bleed)
	await seconds(0.6)
	var hit := Hitbox.new()
	add_child(hit)
	hit.damage = 0.0
	hit.bleed = 100.0
	var hp_bleed := bleeder.health.current
	bleeder._on_hurt(hit)
	check(is_equal_approx(hp_bleed - bleeder.health.current, 60.0) and bleeder.bleed == 0.0, "кровотечение вырвалось: минус 20 %% здоровья (%.0f)" % (hp_bleed - bleeder.health.current))
	bleeder._add_bleed(50.0)
	bleeder._bleed_delay = 0.0
	await seconds(0.5)
	check(bleeder.bleed < 50.0, "без ударов кровотечение спадает (%.0f)" % bleeder.bleed)
	game_state.mastery[&"sword"] = 170.0
	await tap("attack")
	check(player.sword_hitbox.bleed == 0.0, "до последней ступени кровотечения нет")
	game_state.mastery[&"sword"] = 1000.0
	hit.free()
	await seconds(0.6)
	rooms._rest()
	await seconds(1.0)
	print("== Заряженный удар")
	await put(Vector3(-16.0, 0.1, 0))
	await seconds(0.2)
	var stamina_full := player.stamina
	press("attack")
	await seconds(0.55)
	check(player.state == Player.State.CHARGE, "держит удар — заряд после взмаха")
	await seconds(0.65)
	check(player._charge_ready, "заряд полон")
	release("attack")
	await frames(3)
	check(player._step == player.weapon.charged and player.state == Player.State.ATTACK, "отпустил — заряженный удар")
	check(player.stamina < stamina_full, "заряженный стоит выносливости")
	await seconds(0.9)
	press("attack")
	await seconds(0.45)
	release("attack")
	await frames(3)
	check(player.state != Player.State.ATTACK or player._step != player.weapon.charged, "отпустил раньше — заряженного нет")
	await seconds(0.5)
	print("== Удар в прыжке и контрудар")
	press("jump")
	await seconds(0.2)
	release("jump")
	await tap("attack")
	check(player._step == player.weapon.air_attack, "в прыжке — рез в прыжке")
	await seconds(1.0)
	player._counter_t = 0.3
	await tap("attack")
	check(player._step == player.weapon.counter, "после блока — контрудар")
	await seconds(0.6)
	print("== Закалённое стекло")
	game_state.add_echoes(100 - game_state.echoes)
	game_state.items.erase(&"tempered_glass")
	check(not game_state.temper(&"sword"), "без материала не закалить")
	game_state.add_item(&"tempered_glass")
	check(game_state.temper(&"sword") and game_state.glass_level(&"sword") == 1 and game_state.echoes == 0,
		"закалка +1 за стекло и отзвуки")
	check(is_equal_approx(player._blade_damage(), stats.sword_damage * 1.12), "урон клинка +12 %")
	game_state.weapon_glass.clear()
	game_state.items.erase(&"tempered_glass")
	# Дальше проверяем старые механики: парирование открыто, серия как у новичка не важна.
	game_state.mastery.clear()
	game_state.mastery[&"sword"] = 160.0
	player.restore()
	check(player.flasks == player.stats.flask_charges, "отдых пополнил зелье (%d)" % player.flasks)
	var chest_flags: Dictionary = game_state.flags.duplicate()

	print("== Отзвуки врагов и память мира")
	var victim := room_node("Objects/Soldier") as Dummy
	var victim_path := rooms.current_room.get_path_to(victim)
	var echoes_before: int = game_state.echoes
	var worth := victim.echoes
	victim.health.take_damage(INF)
	await seconds(2.5)
	check(game_state.echoes == echoes_before + worth,
		"отзвук врага долетел до героя (+%d из %d)" % [game_state.echoes - echoes_before, worth])
	rooms._load_room(rooms.reality)
	await frames(2)
	check(room_node(String(victim_path)) == null, "комната пересоздана без отдыха (как при переходе через зеркало) — враг мёртв")
	rooms._rest()
	await seconds(1.0)
	check(room_node(String(victim_path)) != null, "отдых у осколка — враг снова на месте")
	check(game_state.flags == chest_flags, "отдых не трогает открытые сундуки")

	print("== Прицел стиком")
	press("shoot")
	Input.action_press("aim_left")
	Input.action_press("aim_up")
	await frames(4)
	check(player.aim_source == Player.Aim.STICK and player.facing < 0.0 and absf(rad_to_deg(player._aim_angle()) - 45.0) < 1.0,
		"правый стик влево-вверх — лук влево-вверх на 45°")
	Input.action_release("aim_left")
	Input.action_release("aim_up")
	await frames(2)
	check(absf(rad_to_deg(player._aim_angle()) - 45.0) < 1.0, "стик отпущен — направление осталось")
	release("shoot")
	await seconds(0.6)
	player.aim_source = Player.Aim.BUTTONS

	print("== Прицел мышью")
	var aim_from := player.global_position + Vector3(0.0, player.BOW_HEIGHT, 0.0)
	var up_left := player.aim_toward(aim_from + Vector3(-3.0, 3.0, 0.0))
	check(player.facing < 0.0 and absf(rad_to_deg(up_left) - 45.0) < 0.5,
		"курсор вверху слева — герой развернулся, лук на 45° (%.1f°)" % rad_to_deg(up_left))
	var down_right := player.aim_toward(aim_from + Vector3(2.0, -2.0, 0.0))
	check(player.facing > 0.0 and absf(rad_to_deg(down_right) + 45.0) < 0.5,
		"курсор внизу справа — лук на −45° (%.1f°)" % rad_to_deg(down_right))
	check(player.aim_source == Player.Aim.BUTTONS, "без мыши и стика — прицел клавишами, как раньше")

	print("== Башня проходится в обе стороны")
	check(player.state == Player.State.MOVE and not player.frozen, "герой свободен (состояние %d)" % player.state)
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

	print("== Зацеп за уступ")
	# Без ввода к краю — не цепляется, падает мимо.
	await put(Vector3(-9.1, 5.5, 0), 1.0)
	await seconds(0.25)
	check(player.state != Player.State.LEDGE_HANG, "без ввода к краю — не цепляется")
	# Падает у края уступа, держа «вправо» — повисает на руках.
	await put(Vector3(-9.1, 5.5, 0), 1.0)
	press("move_right")
	var hung := false
	for i in 40:
		await frames(1)
		if player.state == Player.State.LEDGE_HANG:
			hung = true
			break
	release("move_right")
	check(hung, "держит «к краю» — повис на уступе")
	check(absf(player.global_position.y - (7.0 - player.stats.ledge_hang_depth)) < 0.05, \
		"висит на руках: ноги на %.2f ниже края" % (7.0 - player.global_position.y))
	await seconds(0.4)
	check(player.state == Player.State.LEDGE_HANG, "отпустил ввод — продолжает висеть")
	press("move_up")
	await seconds(0.45)
	release_all()
	var stood := player.is_on_floor() and absf(player.global_position.y - 7.0) < 0.1
	check(stood and player.global_position.x > -8.5, \
		"«вверх» — подтянулся на уступ (%.2f, %.2f)" % [player.global_position.x, player.global_position.y])
	# «Вниз» — отпускается.
	await put(Vector3(-9.1, 5.5, 0), 1.0)
	press("move_right")
	for i in 40:
		await frames(1)
		if player.state == Player.State.LEDGE_HANG:
			break
	release("move_right")
	await frames(3)
	await tap("move_down")
	await seconds(0.2)
	check(player.state == Player.State.MOVE and player.global_position.y < 5.0, \
		"«вниз» — отпустил край (y=%.2f)" % player.global_position.y)
	# Низкий прыжок с верха башни к уступу: держим «вправо» — цепляется и встаёт на уступ.
	await put(Vector3(-12.0, 6.1, 0), 1.0)
	press("move_right")
	var grabbed := false
	for i in 120:
		await frames(1)
		if player.global_position.x > -11.25 and not grabbed and player.is_on_floor():
			await tap("jump")
		if player.state in [Player.State.LEDGE_HANG, Player.State.LEDGE_CLIMB]:
			grabbed = true
		if grabbed and player.state == Player.State.MOVE and player.is_on_floor():
			break
	release_all()
	await seconds(0.2)
	var on_upper := player.is_on_floor() and absf(player.global_position.y - 7.0) < 0.1
	check(grabbed and on_upper, "низкий прыжок с башни: зацепился и встал на уступ (%.2f, %.2f)" \
		% [player.global_position.x, player.global_position.y])

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
	# Перекат проходит сквозь любого врага и выводит за спину (§6.3, 2026-11-09).
	player.restore()
	player._since_roll = 99.0
	press("move_right")
	await tap("roll")
	await seconds(0.9)
	release_all()
	check(player.global_position.x > soldier.global_position.x + 0.3, "перекат сквозь рядового врага — за спиной")
	await seconds(0.3)
	check(player.global_position.x > soldier.global_position.x, "после переката враг снова твёрдый, герой снаружи")
	# Реакции на удар по тяжести: лёгкий — вздрог, средний — осечка вне атаки.
	var jab := Hitbox.new()
	rooms.current_room.add_child(jab)
	jab.damage = 1.0
	jab.poise_damage = 8.0
	jab.global_position = soldier.global_position + Vector3(-1.0, 1.0, 0.0)
	soldier._set_state(Dummy.State.WINDUP)
	soldier._on_hurt(jab)
	check(soldier.state == Dummy.State.WINDUP and soldier._jolt > 0.0, "лёгкий удар — враг вздрогнул, замах не сбит")
	jab.poise_damage = 18.0
	soldier._on_hurt(jab)
	check(soldier.state == Dummy.State.WINDUP, "в замахе удар меча не сбивает — сверхброня")
	soldier.poise = soldier.max_poise
	soldier._set_state(Dummy.State.RECOVER)
	soldier._on_hurt(jab)
	check(soldier.state == Dummy.State.FLINCH, "в откате удар меча — осечка")
	soldier.poise = soldier.max_poise
	soldier._set_state(Dummy.State.ATTACK)
	soldier._on_hurt(jab)
	check(soldier.state == Dummy.State.ATTACK, "в собственном ударе не осекается — размен")
	jab.queue_free()
	soldier.attack_hitbox.active = false
	soldier.health.heal_full()
	soldier.poise = soldier.max_poise
	soldier._set_state(Dummy.State.PATROL)

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
	sfx.history.clear()
	var hp0 := soldier.health.current
	var staggered := false
	for i in 3:
		await tap("attack")
		for k in 12:
			await frames(1)
			staggered = staggered or soldier.state == Dummy.State.STAGGER
	# Выпад с замахом бьёт позже нажатия (§6.1): ждём, пока он отыграет.
	for k in 30:
		await frames(1)
		staggered = staggered or soldier.state == Dummy.State.STAGGER
	check(steps_seen == [1, 2, 3], "три стадии подряд (%s)" % str(steps_seen))
	check(player.weapon.combo[2].heavy, "выпад — тяжёлый удар")
	check(soldier.health.current < hp0, "комбо попало по врагу")
	check(staggered, "стойкость сломана — стаггер")
	check(sfx.history.count(&"sword_swing") == 2 and sfx.history.count(&"sword_swing_thrust") == 1 \
		and heard(&"enemy_hurt"), "звуки: два режущих взмаха, колющий выпад, враг получил удар")
	var hits: Array = sfx.history.filter(func(e: StringName) -> bool: return e in [&"sword_hit", &"sword_hit_finisher"])
	check(hits.size() >= 2 and hits.back() == &"sword_hit_finisher" and hits.front() == &"sword_hit", \
		"удары серии звучат одинаково, третий — завершающий (%s)" % str(hits))
	soldier.detect_range = 7.0
	soldier.backstab_allowed = true
	await seconds(1.0)

	print("== Блок")
	player.restore()
	await face_enemy(soldier)
	sfx.history.clear()
	press("block")
	await wait_windup(soldier, 0.1)
	var hp_block := player.health.current
	await wait_attack_over(soldier)
	check(player.health.current == hp_block, "удар спереди принят на блок без урона")
	check(player.stamina < player.stats.max_stamina, "блок стоил выносливости (%.0f)" % player.stamina)
	check(heard(&"sword_block"), "звук блока")
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
	sfx.history.clear()
	await tap("attack")
	check(player.state == Player.State.CRITICAL and last_step == player.weapon.backstab, "удар сзади — удар в спину")
	check(soldier.state == Dummy.State.CRITICAL_HIT, "враг зафиксирован")
	await seconds(0.7)
	check(soldier.visual.position.y > 0.3, "враг висит на клинке (подъём %.2f)" % soldier.visual.position.y)
	check(soldier.health.current == hp_bs, "урон ещё не прошёл — клинок в спине")
	await seconds(0.4)
	var bs_damage := hp_bs - soldier.health.current
	check(absf(bs_damage - player.stats.sword_damage * 3.5) < 1.0, "урон удара в спину ×3.5 (%.1f)" % bs_damage)
	check(heard(&"critical_pierce") and heard(&"critical_release"), "звуки: клинок входит, рывок")
	await seconds(1.5)
	soldier.detect_range = 7.0

	print("== Парирование и добивание")
	player.restore()
	await seconds(0.5)
	await face_enemy(soldier)
	await wait_windup(soldier, 0.08)
	var hp_parry := player.health.current
	sfx.history.clear()
	await tap("block")
	await seconds(0.2)
	check(soldier.state == Dummy.State.OFF_BALANCE, "парирование: враг потерял равновесие (state=%d)" % soldier.state)
	check(player.health.current == hp_parry, "парирование без урона")
	check(heard(&"sword_parry"), "звук парирования")
	var hp_rip := soldier.health.current
	await tap("attack")
	check(player.state == Player.State.CRITICAL and last_step == player.weapon.riposte, "удар по потерявшему равновесие — добивание")
	check(player.hurtbox.invulnerable, "в добивании герой неуязвим")
	await seconds(0.95)
	var rip_damage := hp_rip - soldier.health.current
	check(absf(rip_damage - player.stats.sword_damage * 3.0) < 1.0, "урон добивания ×3 (%.1f)" % rip_damage)
	await seconds(1.6)

	print("== Раннее парирование: окно 0.23 с")
	player.restore()
	await seconds(0.5)
	await face_enemy(soldier)
	await wait_windup(soldier, 0.19)
	var hp_early := player.health.current
	await tap("block")
	await seconds(0.3)
	check(soldier.state == Dummy.State.OFF_BALANCE, "блок за ~0.2 с до удара — парирование (state=%d)" % soldier.state)
	check(player.health.current == hp_early, "раннее парирование без урона")
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

	print("== Щит: парирует сразу, блок дешевле")
	var soldier_at := soldier.global_position
	var soldier_facing := soldier.facing
	var mastery_saved: Dictionary = game_state.mastery.duplicate()
	game_state.mastery.clear()
	player.restore()
	check(not player.can_parry(), "без щита и мастерства — только блок")
	game_state.add_item(GameState.SHIELD_ITEM)
	await frames(2)
	check(player.shield_in_hand() and player.can_parry() and player.arms.shield_at == PlayerArms.ShieldAt.HAND,
		"щит в руке — парирует без ступени мастерства")
	await seconds(0.5)
	await face_enemy(soldier)
	await wait_windup(soldier, 0.08)
	var hp_shield := player.health.current
	await tap("block")
	await seconds(0.2)
	check(soldier.state == Dummy.State.OFF_BALANCE and player.health.current == hp_shield, "щитом парировал (state=%d)" % soldier.state)
	await seconds(1.8)
	player.restore()
	await face_enemy(soldier)
	press("block")
	await frames(3)
	check(player.arms.shield_at == PlayerArms.ShieldAt.GUARD, "в блоке щит выставлен вперёд")
	await wait_windup(soldier, 0.1)
	player._stamina_delay = 10.0
	var stamina_shield := player.stamina
	await wait_attack_over(soldier)
	var shield_cost := stamina_shield - player.stamina
	var weapon_cost: float = soldier.attack_hitbox.damage * player.stats.block_stamina_mult
	check(absf(shield_cost - weapon_cost * Player.SHIELD_BLOCK_MULT) < 1.0, "блок щитом дешевле: %.1f вместо %.1f" % [shield_cost, weapon_cost])
	release_all()
	player._stamina_delay = 0.0
	await seconds(1.2)

	print("== Подсвечник: удары молота")
	player.restore()
	player.equip(&"candlestick")
	await frames(2)
	check(player.weapon.type == &"hammer" and player.weapon.two_handed and player.arms.sword_pivot.find_child("Head", false, false) != null,
		"подсвечник — двуручный молот с навершием")
	check(player.arms.shield_at == PlayerArms.ShieldAt.BACK and not player.can_parry(), "с двуручным щит за спиной, парирования нет")
	check(game_state.owned_weapons().has(&"candlestick") and game_state.owned_weapons().has(&"sword"), "меч остался с собой")
	check(player._series().size() == 2, "до мастерства — два удара серии")
	game_state.mastery[&"hammer"] = 50.0
	check(player._series().size() == 3 and player._series()[2] == player.weapon.extra_hit, "на второй ступени третий удар — сверху")
	await put(Vector3(-16.0, 0.1, 0))
	await seconds(0.3)
	sfx.history.clear()
	await tap("attack")
	for i in 120:
		if player.state == Player.State.ATTACK and player._step == player.weapon.combo[0] and player._state_time > 0.42:
			break
		await frames(1)
	check(absf(player.arms.sword_pivot.rotation.z - player.weapon.combo[0].blade_to) < 0.15,
		"после удара молот лежит в конце взмаха (%.2f)" % player.arms.sword_pivot.rotation.z)
	await tap("attack")
	for i in 120:
		if player._step == player.weapon.combo[1] and player._state_time > 0.3:
			break
		await frames(1)
	check(player._step == player.weapon.combo[1], "второй — подхват")
	await tap("attack")
	for i in 120:
		if player._step == player.weapon.extra_hit and player._state_time > 0.5:
			break
		await frames(1)
	check(player._step == player.weapon.extra_hit and heard(&"sword_block"), "третий — удар сверху, молот бьёт в пол")
	await seconds(1.0)
	player.restore()
	press("attack")
	await seconds(1.5)
	check(player.state == Player.State.CHARGE and player._charge_ready, "держит удар — заряд")
	release("attack")
	await frames(3)
	check(player._step == player.weapon.charged, "отпустил — раскрутка")
	await seconds(0.65)
	check(player.state == Player.State.ATTACK and player._step == player.weapon.charged.follow_up, "раскрутка сама переходит в удар сверху")
	await seconds(1.2)
	game_state.mastery = mastery_saved
	game_state.items.erase(GameState.SHIELD_ITEM)
	player.equip(&"sword")
	check(player.arms.shield_at == PlayerArms.ShieldAt.NONE and player.weapon.id == &"sword", "щит убран, в руке снова меч")
	# Парирование и удары молота сдвинули и развернули солдата; дальше его ждут на прежнем месте.
	soldier.global_position = soldier_at
	soldier.facing = soldier_facing
	soldier._set_state(Dummy.State.PATROL)

	print("== Лук: быстрый и натянутый выстрел")
	soldier = room_node("Objects/Soldier") as Dummy
	player.restore()
	await face_enemy(soldier, 5.0)
	var hp_arrow := soldier.health.current
	await shoot(0.0)
	var quick_speed := last_arrow_speed
	await seconds(0.5)
	check(soldier.health.current < hp_arrow, "быстрая стрела попала (%.0f → %.0f)" % [hp_arrow, soldier.health.current])
	await put(Vector3(-20, 0.1, 0), -1.0)
	await shoot(0.7)
	check(last_arrow_speed > quick_speed * 1.5, "натянутая стрела быстрее (%.1f против %.1f)" % [last_arrow_speed, quick_speed])
	await seconds(0.6)

	print("== Расходники: крестовина и броски (§8.12)")
	# Солдат стоит на месте: бросок проверяет полёт, а не погоню. В конце всё возвращаем.
	var soldier_home := soldier.global_position
	var soldier_look := soldier.facing
	var soldier_patrol := soldier.patrol_speed
	var soldier_chase := soldier.chase_speed
	soldier.patrol_speed = 0.0
	soldier.chase_speed = 0.0
	player.restore()
	game_state.add_item(&"throwing_knife", 3)
	check(game_state.quick_item(0) == &"throwing_knife", "нож сам лёг в верхнюю ячейку крестовины")
	var cross := rooms.hud.get_node("QuickCross") as Control
	check(cross != null and cross.visible, "крестовина расходников в HUD")
	var thrown_items: Array[Thrown] = []
	var on_throw := func(t: Thrown) -> void: thrown_items.append(t)
	player.item_thrown.connect(on_throw)
	await face_enemy(soldier, 4.0)
	var hp_knife := soldier.health.current
	# Как в Dark Souls: клавиша ячейки только выбирает, бросает G.
	await tap("quick_1")
	await seconds(0.3)
	check(thrown_items.is_empty() and game_state.active_quick == 0, "клавиша 1 — только выбор ячейки, без броска")
	await tap("quick_use")
	await seconds(0.5)
	check(thrown_items.size() == 1 and game_state.item_count(&"throwing_knife") == 2,
		"G — бросок ножа из выбранной ячейки, осталось %d" % game_state.item_count(&"throwing_knife"))
	var chosen_cell := cross.get_node("Slot1") as Control
	check(chosen_cell.scale.x > 1.05 and (cross.get_node("Slot2") as Control).scale.x < 1.01, "выбранная ячейка в HUD выделена")
	# Геймпад: тап правого курка без крестовины — бросок выбранного.
	player.restore()
	await seconds(0.3)
	await tap("quick_hold")
	await seconds(0.5)
	check(thrown_items.size() == 2, "тап правого курка — бросок выбранного")
	check(soldier.health.current < hp_knife, "нож попал (%.0f → %.0f)" % [hp_knife, soldier.health.current])
	game_state.add_item(&"fire_flask")
	check(game_state.quick_item(1) == &"fire_flask", "склянка легла в левую ячейку")
	await face_enemy(soldier, 5.5)
	var hp_fire := soldier.health.current
	await use_slot(1)
	await seconds(1.0)
	check(soldier.health.current < hp_fire, "склянка разбилась вспышкой (%.0f → %.0f)" % [hp_fire, soldier.health.current])
	check(game_state.item_count(&"fire_flask") == 0, "склянок не осталось")
	await use_slot(1)
	await frames(3)
	check(player.state != Player.State.THROW and thrown_items.size() == 3, "кончились — броска нет")
	game_state.set_quick_slot(3, &"throwing_knife")
	check(game_state.quick_item(3) == &"throwing_knife" and game_state.quick_item(0) == &"",
		"нож переложен вниз: предмет лежит в одной ячейке")
	player.item_thrown.disconnect(on_throw)
	game_state.items.erase(&"throwing_knife")
	game_state.items.erase(&"fire_flask")
	game_state.quick_slots = [&"", &"", &"", &""]
	Events.quick_items_changed.emit()
	soldier.patrol_speed = soldier_patrol
	soldier.chase_speed = soldier_chase
	soldier.health.heal_full()
	soldier.global_position = soldier_home
	soldier.facing = soldier_look
	soldier.velocity = Vector3.ZERO
	soldier._set_state(Dummy.State.PATROL)
	player.restore()
	await seconds(0.3)

	print("== Склянки: заряд броска, яд, кислота, смола, огненные стрелы, святая вода (§6.2)")
	# Солдат снова стоит на месте и не умрёт: здоровья на всё. В конце всё возвращаем.
	soldier_home = soldier.global_position
	soldier_look = soldier.facing
	var soldier_max := soldier.health.max_health
	soldier.patrol_speed = 0.0
	soldier.chase_speed = 0.0
	soldier.health.max_health = 2000.0
	soldier.health.heal_full()
	var clear_zones := func() -> void:
		for node in nodes_where(get_tree().root, func(n: Node) -> bool: return n is FlaskZone or n is Thrown):
			node.free()
		soldier.statuses.clear()
		player.statuses.clear()
		player.restore()
	clear_zones.call()
	# Скорость склянки — в момент броска: долетев, она разбивается и исчезает.
	var flask_speeds: Array[float] = []
	var on_flask := func(t: Thrown) -> void: flask_speeds.append(t.velocity.length())
	player.item_thrown.connect(on_flask)
	# Заряд: тап — обычный бросок, удержание ячейки — дальше (быстрее).
	game_state.add_item(&"poison_flask", 4)
	game_state.set_quick_slot(0, &"poison_flask")
	await put(Vector3(-20, 0.1, 0), -1.0)
	await use_slot(0)
	await seconds(0.4)
	press("quick_use")
	await seconds(0.6)
	release("quick_use")
	await seconds(0.4)
	check(flask_speeds.size() == 2, "два броска склянки: тап и с задержкой")
	if flask_speeds.size() == 2:
		check(player.throw_charge >= 0.99, "задержка: заряд полный (%.2f)" % player.throw_charge)
		check(flask_speeds[1] > flask_speeds[0] * 1.3, "с задержкой — дальше (%.1f против %.1f м/с)" % [flask_speeds[1], flask_speeds[0]])
	await seconds(1.2)
	clear_zones.call()
	# Яд: облако травит солдата со временем и героя, если он в нём стоит.
	await face_enemy(soldier, 5.0)
	await use_slot(0)
	await seconds(1.0)
	var cloud := nodes_where(get_tree().root, func(n: Node) -> bool: return n is PoisonCloud)
	check(not cloud.is_empty(), "склянка с ядом оставила облако")
	check(soldier.statuses.has(Statuses.POISON), "солдат отравлен")
	var hp_poison := soldier.health.current
	await seconds(1.5)
	check(soldier.health.current < hp_poison, "яд ранит со временем (%.0f → %.0f)" % [hp_poison, soldier.health.current])
	if not cloud.is_empty():
		await put(Vector3((cloud[0] as Node3D).global_position.x, 0.1, 0), -soldier.facing)
		await seconds(0.6)
		check(player.statuses.has(Statuses.POISON) and player.has_effect(&"poison"), "облако травит и героя, значок «яд» в HUD")
	clear_zones.call()
	# Кислота: по разъеденному бьют больнее.
	game_state.add_item(&"acid_flask")
	game_state.set_quick_slot(0, &"acid_flask")
	await face_enemy(soldier, 5.0)
	await use_slot(0)
	await seconds(1.0)
	check(soldier.statuses.has(Statuses.CORRODED), "кислота разъела броню солдата")
	var hp_acid := soldier.health.current
	soldier.health.take_damage(10.0)
	check(is_equal_approx(hp_acid - soldier.health.current, 10.0 * Statuses.CORRODED_DAMAGE), "по разъеденному больнее (−%.1f)" % (hp_acid - soldier.health.current))
	clear_zones.call()
	# Смола: враг объят смолой, лужа держится; огненная стрела — взрыв.
	game_state.add_item(&"tar_flask")
	game_state.set_quick_slot(0, &"tar_flask")
	await face_enemy(soldier, 5.0)
	await use_slot(0)
	await seconds(1.0)
	check(soldier.statuses.has(Statuses.TAR) and soldier.statuses.speed_mult() < 0.5, "солдат объят смолой и еле двигается")
	check(not nodes_where(get_tree().root, func(n: Node) -> bool: return n is TarPool).is_empty(), "смола лежит на земле")
	game_state.add_item(&"fire_arrow", 2)
	check(game_state.arrow_slots[1] == &"fire_arrow" and game_state.current_arrow() == &"", "огненные стрелы легли во второе гнездо, в руке обычные")
	await tap("arrow_swap")
	check(game_state.current_arrow() == &"fire_arrow", "смена стрел: теперь огненные")
	await seconds(0.3)
	check(rooms.hud._arrow_count.visible and rooms.hud._arrow_count.text == "2", "HUD: значок огненных стрел у лука, их 2")
	var hp_tar := soldier.health.current
	await face_enemy(soldier, 5.0)
	await shoot(0.5)
	await seconds(0.8)
	check(game_state.item_count(&"fire_arrow") == 1, "огненная стрела потрачена")
	check(not soldier.statuses.has(Statuses.TAR) and hp_tar - soldier.health.current > 40.0,
		"огонь по смоле — взрыв (%.0f → %.0f)" % [hp_tar, soldier.health.current])
	check(nodes_where(get_tree().root, func(n: Node) -> bool: return n is TarPool).is_empty(), "смола на земле сгорела")
	await shoot(0.2)
	await seconds(0.5)
	check(game_state.item_count(&"fire_arrow") == 0 and game_state.current_arrow() == &"", "огненные кончились — гнездо стреляет обычными")
	game_state.active_arrow = 0
	game_state.arrow_slots = [&"", &""]
	game_state.items.erase(&"fire_arrow")
	clear_zones.call()
	# Святая вода: нежить горит во много раз сильнее, свет остаётся.
	game_state.add_item(&"holy_flask", 2)
	game_state.set_quick_slot(0, &"holy_flask")
	await face_enemy(soldier, 5.0)
	var hp_holy := soldier.health.current
	await use_slot(0)
	await seconds(1.0)
	var plain_holy := hp_holy - soldier.health.current
	check(not nodes_where(get_tree().root, func(n: Node) -> bool: return n is HolyLight).is_empty(), "свет святой воды остался в комнате")
	soldier.unholy = true
	hp_holy = soldier.health.current
	await face_enemy(soldier, 5.0)
	await use_slot(0)
	# Крест появляется, когда склянка долетит и разобьётся, и живёт меньше секунды.
	var crossed := false
	for i in 90:
		await frames(1)
		if not nodes_where(get_tree().root, func(n: Node) -> bool: return n is HolyCross).is_empty():
			crossed = true
			break
	await seconds(1.0)
	var unholy_holy := hp_holy - soldier.health.current
	check(crossed and unholy_holy > plain_holy * 4.0, "нежить: крест из света и урон ×%.1f (%.0f против %.0f)" % [unholy_holy / maxf(plain_holy, 0.01), unholy_holy, plain_holy])
	soldier.unholy = false
	player.item_thrown.disconnect(on_flask)
	for id: StringName in [&"poison_flask", &"acid_flask", &"tar_flask", &"holy_flask"]:
		game_state.items.erase(id)
	game_state.quick_slots = [&"", &"", &"", &""]
	Events.quick_items_changed.emit()
	clear_zones.call()
	soldier.health.max_health = soldier_max
	soldier.health.heal_full()
	soldier.patrol_speed = soldier_patrol
	soldier.chase_speed = soldier_chase
	soldier.global_position = soldier_home
	soldier.facing = soldier_look
	soldier.velocity = Vector3.ZERO
	soldier._set_state(Dummy.State.PATROL)
	await seconds(0.3)

	print("== Слепота: общий эффект, своя реакция у каждого класса врага (§6.2, §6.3)")
	# Солдат стоит на месте; в конце всё возвращаем.
	soldier_home = soldier.global_position
	soldier_look = soldier.facing
	soldier.patrol_speed = 0.0
	soldier.chase_speed = 0.0
	player.restore()
	await face_enemy(soldier, 1.6)
	check(soldier.model != null and soldier.model.sword() != null and soldier.creature == CreatureKind.Kind.HUMAN,
		"солдат-человек — манекен героя с мечом")
	soldier.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
	check(soldier.state == Dummy.State.BLINDED and soldier.blind_reaction == CreatureKind.Reaction.RUB_EYES
		and is_equal_approx(soldier.statuses.time_left(Statuses.BLIND), Statuses.BLIND_TIME), "солдат ослеп на 4 с: человек трёт глаза")
	await seconds(0.6)
	var palm_gap := maxf(soldier.model.hand_point(0).distance_to(soldier.model.eye_point()),
		soldier.model.hand_point(1).distance_to(soldier.model.eye_point()))
	check(soldier.blind_recoiling() and palm_gap < 0.3, "первую секунду отшатнулся, обе ладони у глаз (%.2f м)" % palm_gap)
	check(soldier.model.sword().get_parent() == soldier.model.hero.hand and soldier.model.hero.hand.rotation.length() < 0.25,
		"меч в руке и лежит вдоль кисти и предплечья")
	var hp_blind := soldier.health.current
	await tap("attack")
	await seconds(0.5)
	check(soldier.health.current < hp_blind and soldier.state == Dummy.State.BLINDED, "удар ранит, но из слепоты не выводит")
	check(not soldier.can_be_riposted(), "человека в слепоте спереди не добить")
	await seconds(0.3)
	check(soldier.state == Dummy.State.BLINDED and not soldier.blind_recoiling(), "дальше трёт глаза и не нападает, хоть герой рядом")
	for i in 300:
		if soldier.state != Dummy.State.BLINDED:
			break
		await frames(1)
	check(soldier.state != Dummy.State.BLINDED and not soldier.statuses.has(Statuses.BLIND), "слепота прошла — снова в бою")
	# Привыкание: второе ослепление за бой короче; сопротивление укорачивает ещё.
	soldier.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
	check(is_equal_approx(soldier.statuses.time_left(Statuses.BLIND), Statuses.BLIND_TIME * Dummy.BLIND_HABIT),
		"второй раз за бой — короче (%.1f с)" % soldier.statuses.time_left(Statuses.BLIND))
	soldier.statuses.remove(Statuses.BLIND)
	check(soldier.state == Dummy.State.CHASE, "слепоту сняли — враг снова в бою")
	soldier._blind_count = 0
	soldier.blind_resistance = 0.5
	soldier.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
	check(is_equal_approx(soldier.statuses.time_left(Statuses.BLIND), Statuses.BLIND_TIME * 0.5), "сопротивление 0.5 — вдвое короче")
	soldier.statuses.remove(Statuses.BLIND)
	soldier.blind_resistance = 0.0
	soldier._blind_count = 0
	soldier.creature = CreatureKind.Kind.SKELETON
	soldier.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
	check(not soldier.statuses.has(Statuses.BLIND) and soldier.state != Dummy.State.BLINDED, "скелета не ослепить: глаз нет")
	player.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
	check(not player.statuses.has(Statuses.BLIND), "герой пока не слепнет (решено на потом)")
	# Вампир: слепота дезориентирует — окно для добивания спереди.
	soldier.creature = CreatureKind.Kind.VAMPIRE
	await face_enemy(soldier, 1.2)
	soldier.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
	check(soldier.blind_reaction == CreatureKind.Reaction.DISORIENT and soldier.can_be_riposted()
		and is_equal_approx(soldier.statuses.time_left(Statuses.BLIND), Statuses.BLIND_TIME * 0.75), "вампир дезориентирован на 3 с: можно добить спереди")
	await seconds(0.3)
	await tap("attack")
	check(player.state == Player.State.CRITICAL, "удар по ослеплённому вампиру спереди — добивание")
	await seconds(2.5)
	check(not soldier.statuses.has(Statuses.BLIND), "после добивания слепоты нет")
	soldier.creature = CreatureKind.Kind.HUMAN
	soldier._blind_count = 0
	# Враги леса и босс: у каждого класса своя реакция и своё время.
	var classes := {
		"vampire": [CreatureKind.Reaction.DISORIENT, 0.75],
		"rat": [CreatureKind.Reaction.SHAKE_HEAD, 0.5], "bat": [CreatureKind.Reaction.IMMUNE, 0.0],
		"fog_wraith": [CreatureKind.Reaction.FADE, 0.5], "glass_crawler": [CreatureKind.Reaction.IMMUNE, 0.0],
		"drowned_knight": [CreatureKind.Reaction.IMMUNE, 0.0], "werewolf": [CreatureKind.Reaction.ROAR, 0.5],
		"blacksmith": [CreatureKind.Reaction.RUB_EYES, 0.5], "bandit_heavy": [CreatureKind.Reaction.RUB_EYES, 1.0],
		"bandit_knife": [CreatureKind.Reaction.RUB_EYES, 1.0],
	}
	for id: String in classes:
		var foe := (load("res://actors/enemies/%s.tscn" % id) as PackedScene).instantiate() as Dummy
		# Не спит и не уходит: проверяем только реакцию.
		foe.dormant = false
		if foe is Werewolf:
			(foe as Werewolf).gone_flag = &"test_never_set"
		if foe is Blacksmith:
			(foe as Blacksmith).boss_flag = &"test_never_set"
		soldier.get_parent().add_child(foe)
		foe.global_position = soldier_home + Vector3(60.0, 1.0, 0.0)
		await frames(2)
		if foe is Bat:
			(foe as Bat)._awake = true
		foe.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
		var want: Array = classes[id]
		var reaction: CreatureKind.Reaction = want[0]
		var ok := not foe.statuses.has(Statuses.BLIND) and foe.state != Dummy.State.BLINDED
		if reaction != CreatureKind.Reaction.IMMUNE:
			ok = foe.state == Dummy.State.BLINDED and foe.blind_reaction == reaction \
				and is_equal_approx(foe.statuses.time_left(Statuses.BLIND), Statuses.BLIND_TIME * want[1])
		# Руки есть у всех гуманоидов: graybox или манекен.
		var has_arms := foe.arms != null or foe.model != null
		var humanoid_arms := has_arms == (reaction in [CreatureKind.Reaction.RUB_EYES, CreatureKind.Reaction.DISORIENT])
		check(ok and humanoid_arms, "%s: %s, %.1f с" % [id, CreatureKind.Reaction.keys()[reaction], foe.statuses.time_left(Statuses.BLIND)])
		# Поза слепоты отыгрывается без ошибок; оружие не покидает руку (общий счётчик теста).
		await seconds(1.4)
		foe.queue_free()
	await frames(2)
	soldier.health.heal_full()
	soldier.patrol_speed = soldier_patrol
	soldier.chase_speed = soldier_chase
	soldier.global_position = soldier_home
	soldier.facing = soldier_look
	soldier.velocity = Vector3.ZERO
	soldier._set_state(Dummy.State.PATROL)
	player.restore()
	await seconds(0.3)

	print("== Меню паузы и наборы оружия I/II (§8.12)")
	var pause_menu := rooms.level_menu
	await put(Vector3(-20, 0.1, 0), 1.0)
	await pause_key()
	check(pause_menu.is_open and not pause_menu.at_shard and player.in_menu and not player.frozen,
		"Esc — меню паузы, мир не стоит (герой не заморожен)")
	var paused_x := player.global_position.x
	press("move_right")
	await seconds(0.3)
	release("move_right")
	check(absf(player.global_position.x - paused_x) < 0.05, "в меню герой не ходит")
	check(pause_menu.pause_panel.visible and not pause_menu._margin.visible and pause_menu.pause_panel.tabs.size() == 5,
		"пауза — компактная панель с пятью вкладками, мир виден")
	pause_menu.show_page(LevelMenu.Page.EQUIP)
	var equip := pause_menu.equipment
	check(pause_menu._pages[LevelMenu.Page.EQUIP].visible and pause_menu._title.text == "Снаряжение"
		and not pause_menu.pause_panel.visible, "вкладка «Снаряжение» — экран ячеек на герое")
	# Расходник в ячейку — из списка; стрелы вне осколка не меняются.
	game_state.add_item(&"throwing_knife", 2)
	equip._choose(EquipmentScreen.Slot.ITEM_4)
	check(equip.list_open(), "ячейка расходника — список выбора")
	equip._put(EquipmentScreen.Slot.ITEM_4, &"throwing_knife")
	check(game_state.quick_item(3) == &"throwing_knife" and not equip.list_open(), "нож в нижнюю ячейку из «Снаряжения»")
	equip._choose(EquipmentScreen.Slot.ARROW_1)
	check(not equip.list_open(), "стрелы вне осколка не меняются")
	# Левая рука: щит снимается и надевается в гнездо I.
	var shield_slots_was: Array = game_state.shield_slots.duplicate()
	game_state.add_item(GameState.SHIELD_ITEM)
	game_state.shield_slots = [GameState.SHIELD_ITEM, &""]
	equip._put(EquipmentScreen.Slot.SHIELD, EquipmentScreen.NONE)
	check(not player.has_shield() and player.arms.shield_at == PlayerArms.ShieldAt.NONE, "щит снят в «Снаряжении»")
	equip._put(EquipmentScreen.Slot.SHIELD_2, GameState.SHIELD_ITEM)
	check(not player.has_shield() and game_state.shield_slots[1] == GameState.SHIELD_ITEM, "щит в гнезде II — не в руке")
	equip._put(EquipmentScreen.Slot.SHIELD, GameState.SHIELD_ITEM)
	check(player.has_shield() and game_state.shield_slots == [GameState.SHIELD_ITEM, &""], "щит снова в руке, гнездо II пусто")
	game_state.shield_slots = shield_slots_was
	game_state.items.erase(GameState.SHIELD_ITEM)
	player.refresh_shield()
	pause_menu.back()
	check(pause_menu._page == LevelMenu.Page.ROOT and pause_menu.pause_panel.visible, "«Назад» — снова панель паузы")
	game_state.items.erase(&"throwing_knife")
	game_state.quick_slots = [&"", &"", &"", &""]
	game_state.active_quick = 0
	Events.quick_items_changed.emit()
	pause_menu.show_page(LevelMenu.Page.WEAPON)
	check(pause_menu._title.text == "Снаряжение" and not pause_menu._temper.visible and pause_menu._shard_note.visible,
		"«Снаряжение»: закалка — только у осколка")
	pause_menu.show_page(LevelMenu.Page.LEVEL)
	check(pause_menu._title.text == "Статус" and not pause_menu._confirm.visible
		and not (pause_menu._buttons[PlayerStats.Param.VIGOR] as Button).visible, "«Статус»: уровень не поднять")
	var volume_was := Settings.volume
	pause_menu.show_page(LevelMenu.Page.SETTINGS)
	pause_menu.change_volume(-Settings.VOLUME_STEP)
	check(is_equal_approx(Settings.volume, maxf(volume_was - Settings.VOLUME_STEP, 0.0)), "«Настройки»: громкость тише")
	Settings.set_volume(volume_was)
	await pause_key()
	check(not pause_menu.is_open and not player.in_menu, "Start/Esc — меню закрыто")
	# Набор II в руку и обратно; пока оружие в пути, удара нет.
	var had_stick: bool = game_state.item_count(&"stick") > 0
	game_state.own_weapon(&"stick")
	game_state.second_weapon_id = &"stick"
	await tap("weapon_swap")
	await frames(1)
	check(player.weapon.id == &"stick" and game_state.second_weapon_id == &"sword", "F — набор II в руке, меч в запасе")
	await tap("attack")
	check(player.state != Player.State.ATTACK, "сразу после смены удара нет")
	await seconds(0.6)
	await tap("weapon_swap")
	await seconds(0.5)
	check(player.weapon.id == &"sword", "смена обратно — снова меч")
	game_state.second_weapon_id = &""
	if not had_stick:
		game_state.items.erase(&"stick")
	await seconds(0.3)

	print("== Стрела не ломает стекло — отскакивает")
	await put(Vector3(-8.0, 0.1, 0), -1.0)
	sfx.history.clear()
	await shoot(0.3)
	var bounced := last_arrow
	await seconds(0.25)
	check(is_instance_valid(bounced) and bounced.ricochets == 1 and bounced.velocity.x > 0.0, "рикошет от стеклянной башни")
	check(not (room_node("Glass/Tower") as GlassSurface)._broken, "башня цела")
	check(heard(&"bow_draw") and heard(&"arrow_ricochet_glass"), "звук лука и рикошета")
	await seconds(0.5)

	print("== Зрение врага по направлению взгляда")
	player.restore()
	soldier.detect_range = 7.0
	soldier._set_state(Dummy.State.PATROL)
	soldier._turn_t = -1.0
	soldier.patrol_speed = 0.0
	# Стоит у края маршрута патруля — развернулся бы сам; маршрут начинается там, где стоит.
	soldier._origin = soldier.global_position
	await put(Vector3(soldier.global_position.x - soldier.facing * 4.0, 0.1, 0), soldier.facing)
	await seconds(0.5)
	check(soldier.state == Dummy.State.PATROL, "сзади на 4 м враг героя не замечает")
	await put(Vector3(soldier.global_position.x + soldier.facing * 4.0, 0.1, 0), -soldier.facing)
	await seconds(0.3)
	check(soldier.state != Dummy.State.PATROL, "спереди на 4 м — замечает (state=%d)" % soldier.state)
	await seconds(0.5)

	print("== Шум стрелы отвлекает — удар в спину")
	soldier._set_state(Dummy.State.PATROL)
	soldier._turn_t = -1.0
	var look := soldier.facing
	await put(Vector3(soldier.global_position.x + look * 9.0, 0.1, 0), -look)
	Arrow.spawn(main, soldier.global_position + Vector3(-look * 3.0, 2.0, 0), Vector3(0, -12, 0), 1.0, 0.0)
	await seconds(0.2)
	check(soldier.state == Dummy.State.INVESTIGATE, "враг пошёл на шум (state=%d)" % soldier.state)
	await seconds(0.6)
	check(soldier.facing == -look, "враг развернулся к шуму — спиной к герою")
	soldier.patrol_speed = 1.8
	await put(Vector3(soldier.global_position.x + look * 1.3, 0.1, 0), -look)
	var hp_noise := soldier.health.current
	await tap("attack")
	check(player.state == Player.State.CRITICAL and last_step == player.weapon.backstab, "удар в спину отвлечённому врагу")
	await seconds(1.2)
	check(soldier.health.current < hp_noise - 50.0, "урон удара в спину прошёл")
	await seconds(1.0)
	soldier._set_state(Dummy.State.PATROL)
	await put(Vector3(soldier.global_position.x + soldier.facing * 4.0, 0.1, 0), -soldier.facing)
	await seconds(0.3)
	Arrow.spawn(main, soldier.global_position + Vector3(-soldier.facing * 3.0, 2.0, 0), Vector3(0, -12, 0), 1.0, 0.0)
	await seconds(0.2)
	check(soldier.state != Dummy.State.INVESTIGATE, "враг, который видит героя, на шум не отвлекается")
	await seconds(1.0)

	print("== Ползун на потолке: сбит стрелой")
	player.restore()
	var hanger := room_node("Objects/CeilingCrawler") as GlassCrawler
	check(hanger._hanging and hanger._drips.emitting, "висит на потолке, с него капает стекло")
	await put(Vector3(17.55, 0.1, 0), 1.0)
	var hp_hanger := hanger.health.current
	await shoot(0.7, true)
	await seconds(1.4)
	check(not hanger._hanging, "стрела сбила ползуна")
	check(hanger.health.current < hp_hanger, "ушибся при падении (hp %.0f → %.0f)" % [hp_hanger, hanger.health.current])
	check(hanger.state == Dummy.State.KNOCKDOWN and hanger.is_on_floor(), "лежит оглушённый (state=%d)" % hanger.state)
	hanger.queue_free()
	await seconds(0.3)

	print("== Стрела-колышек: одна ступенька на один прыжок")
	player.restore()
	await put(Vector3(21.5, 0.1, 0), 1.0)
	await shoot(0.2)
	await seconds(0.3)
	var low_peg := ArrowPeg.current
	check(is_instance_valid(low_peg), "стрела воткнулась в деревянную панель")
	await put(Vector3(22.6, 0.1, 0), 1.0)
	press("jump")
	await seconds(0.3)
	await shoot(0.0)
	release("jump")
	await seconds(0.7)
	var high_peg := ArrowPeg.current
	check(is_instance_valid(high_peg) and high_peg != low_peg and high_peg.global_position.y > 2.6, "вторая стрела выше (y=%.2f)" % (high_peg.global_position.y if high_peg else 0.0))
	var pegs := 0
	for node in main.get_children():
		if node is ArrowPeg and not node.is_queued_for_deletion():
			pegs += 1
	check(pegs == 1, "работает только одна стрела-колышек (%d)" % pegs)
	await put(Vector3(23.2, 0.1, 0), 1.0)
	sfx.history.clear()
	press("jump")
	var used := false
	for i in 40:
		await frames(1)
		if player._peg and player.velocity.y < 1.5:
			release("jump")
			await frames(1)
			press("jump")
			used = true
			break
	await seconds(0.4)
	release("jump")
	await seconds(0.8)
	release_all()
	check(used, "дотянулся до колышка в прыжке")
	check(player.is_on_floor() and player.global_position.y > 3.4, "прыжок от колышка — на тайный уступ (y=%.2f)" % player.global_position.y)
	check(ArrowPeg.current == null, "колышек сломался — второго прыжка нет")
	check(sfx.history.count(&"player_jump") == 2 and sfx.history.count(&"player_jump_voice") == 1, \
		"толчок на обоих прыжках, голос — только от колышка (%d толчка, %d голос)" \
		% [sfx.history.count(&"player_jump"), sfx.history.count(&"player_jump_voice")])
	await seconds(0.5)

	print("== Чистое стекло в нише → сундук")
	player.restore()
	var glass := room_node("Glass/NicheGlass") as GlassSurface
	var chest := room_node("Objects/Chest") as Chest
	check(chest.visible, "сундук виден сквозь чистое стекло")
	await put(Vector3(19.6, 0.1, 0), 1.0)
	var echoes_at_chest: int = game_state.echoes
	await tap("interact")
	check(game_state.echoes == echoes_at_chest, "сквозь целое стекло сундук не открыть")
	await tap("attack")
	await seconds(0.5)
	check(glass._broken, "стекло разбито")
	await tap("interact")
	await seconds(0.2)
	check(game_state.echoes == echoes_at_chest + chest.reward,
		"сундук открыт, отзвуки +%d" % (game_state.echoes - echoes_at_chest))
	check(game_state.item_count(&"facet_blood") == 1, "в сундуке нашлась грань")

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
	sfx.history.clear()
	press("move_right")
	for i in 90:
		await frames(1)
		if player.is_dead():
			break
	release_all()
	check(player.is_dead(), "шагом не успел — упал на шипы")
	check(heard(&"glass_crack"), "стекло треснуло под ногами — звук")
	print("== Смерть: оседает, падает вперёд, оружие выпадает")
	await seconds(0.25)
	check(player.body_mesh.scale.y < 0.85 and player.body_mesh.rotation.z > -0.3, \
		"сначала оседает (scale.y=%.2f)" % player.body_mesh.scale.y)
	check(heard(&"player_knee"), "звук: оседает")
	await seconds(0.85)
	check(absf(player.body_mesh.rotation.z) > 1.4, "лежит (наклон %.2f)" % player.body_mesh.rotation.z)
	var dropped := player.arms.dropped_weapon()
	check(dropped != null and absf(dropped.global_basis.y.normalized().y) < 0.15, \
		"оружие выпало и лежит вдоль пола")
	check(heard(&"weapon_drop") and heard(&"player_body_fall"), "звук: оружие и тело о пол")
	check(heard(&"death_sting") and rooms.hud.death_label.visible, "надпись «ТЫ ПОГИБ» и тон под ней")
	await seconds(2.2)
	check(not player.is_dead(), "герой возродился")
	check(player.arms.dropped_weapon() == null and player.sword_pivot.visible, "оружие снова в руке")
	check(absf(player.global_position.x + 18.5) < 0.6, "возрождение у осколка (x=%.2f)" % player.global_position.x)
	check(room_node("Objects/Soldier") != null, "комната сброшена: враг снова на месте")
	check(room_node("Glass/NicheGlass")._broken, "панель с сундуком осталась разбитой — открытый проход навсегда")
	check((room_node("Objects/Chest") as Chest).opened, "открытый сундук остался открытым")

	print("== Ползун на потолке: засада — падает на героя")
	player.restore()
	var dropper := room_node("Objects/CeilingCrawler") as GlassCrawler
	check(dropper != null and dropper._hanging, "после сброса комнаты снова висит")
	player._iframes = 0.0
	var hp_drop := player.health.current
	await put(Vector3(22.5, 0.1, 0), 1.0)
	await seconds(1.2)
	check(not dropper._hanging, "герой прошёл под ним — упал")
	check(player.health.current < hp_drop, "упал на героя (hp %.0f → %.0f)" % [hp_drop, player.health.current])
	dropper.queue_free()
	player.restore()
	await seconds(0.3)

	print("== Удар вниз пробивает стекло над ямой")
	await put(Vector3(11, 2.5, 0), 1.0)
	sfx.history.clear()
	press("move_down")
	await tap("attack")
	release("move_down")
	await seconds(0.6)
	check(room_node("Glass/TrapGlass")._broken, "стекло пробито ударом вниз")
	check(heard(&"sword_hit_glass") and heard(&"glass_break"), "звук удара по стеклу и разбитого стекла")
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
	rooms._load_room(rooms.reality)
	await frames(2)
	check(room_node("Glass/Slope")._broken, "комната пересоздана без отдыха (как при переходе через зеркало) — скат разбит")
	rooms._rest()
	await seconds(1.0)
	check(not room_node("Glass/Slope")._broken, "отдых у осколка — скат снова цел")
	check(room_node("Glass/NicheGlass")._broken, "отдых не возвращает панель с сундуком")

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

	print("== Люстра: две стрелы — падает в яму и становится платформой")
	player.restore()
	var chandelier := room_node("Objects/Chandelier") as HangingProp
	await put(Vector3(7.5, 0.1, 0), 1.0)
	await shoot(0.7, true)
	await seconds(0.4)
	check(not chandelier.fallen, "одна стрела — люстра ещё держится")
	await shoot(0.7, true)
	await seconds(1.8)
	check(chandelier.fallen and chandelier.landed, "вторая стрела — люстра упала")
	check((room_node("Glass/TrapGlass") as GlassSurface)._broken, "люстра пробила хрупкое стекло")
	await put(Vector3(11, -1.2, 0), 1.0)
	await seconds(0.6)
	check(player.is_on_floor() and not player.is_dead() and player.global_position.y > -1.6, "на люстре в яме можно стоять (y=%.2f)" % player.global_position.y)
	press("move_right")
	press("jump")
	for i in 60:
		await frames(1)
		if player.global_position.x > 13.6:
			break
	release_all()
	await seconds(0.4)
	check(player.global_position.x > 13.0 and player.global_position.y > -0.2, "с люстры выпрыгнул из ямы (%.2f, %.2f)" % [player.global_position.x, player.global_position.y])
	await seconds(3.0)

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

	print("== Ледяной сталактит падает на Отражённого солдата")
	var stalactite := room_node("Objects/IceStalactite") as HangingProp
	mirror_guard.health.max_health = 1000.0
	mirror_guard.health.current = 1000.0
	mirror_guard.patrol_speed = 0.0
	mirror_guard.global_position.x = stalactite.global_position.x
	mirror_guard._set_state(Dummy.State.PATROL)
	await seconds(0.2)
	var hp_ice := mirror_guard.health.current
	Arrow.spawn(main, stalactite.global_position + Vector3(0, -4.0, 0), Vector3(0, 25, 0), 1.0, 0.0)
	await seconds(1.4)
	check(stalactite == null or not is_instance_valid(stalactite) or stalactite.landed, "одна стрела — сталактит упал и разбился")
	check(mirror_guard.health.current <= hp_ice - 39.0, "сталактит ударил врага (hp %.0f → %.0f)" % [hp_ice, mirror_guard.health.current])
	mirror_guard.patrol_speed = 1.8
	await seconds(0.5)

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

	print("== Стеклянный ползун выдувается из мутного стекла")
	var crawler := room_node("Objects/Crawler") as GlassCrawler
	var murky := room_node("Glass/NicheGlassMurky") as GlassSurface
	check(crawler != null and not crawler.visible and crawler.state == Dummy.State.DORMANT, "ползун спит невидимым")
	check(murky.glass_type == GlassSurface.GlassType.MURKY, "стекло мутное")
	player.health.current = 5.0
	await put(Vector3(-18.0, 0.1, 0), -1.0)
	var saw_bubble := false
	for i in 150:
		await frames(1)
		if crawler.visible and crawler.state == Dummy.State.DORMANT:
			saw_bubble = true
		if crawler.state != Dummy.State.DORMANT:
			break
	check(saw_bubble, "из стекла раздувается шарик")
	check(crawler.state != Dummy.State.DORMANT and absf(crawler.global_position.z) < 0.05, "ползун упал в плоскость боя")
	check(murky.glass_type == GlassSurface.GlassType.CLEAR, "тень ушла — стекло стало чистым")
	await seconds(1.5)
	check(not player.is_dead() and player.health.current >= 1.0, "первая засада не убила (hp=%.0f)" % player.health.current)
	crawler.health.max_health = 1000.0
	crawler.health.current = 1000.0
	crawler.attack_hitbox.non_lethal = false

	print("== Кол достаёт издалека")
	player.restore()
	await face_enemy(crawler, 2.3)
	await wait_windup(crawler, 0.05)
	var hp_spike := player.health.current
	await seconds(0.4)
	check(player.health.current < hp_spike, "кол достал героя на 2.3 м (hp %.0f → %.0f)" % [hp_spike, player.health.current])
	await seconds(1.0)

	print("== Стойкость ползуна низкая")
	player.restore()
	await face_enemy(crawler, 1.2)
	player._iframes = 3.0
	crawler.poise = crawler.max_poise
	var crawler_staggered := false
	for i in 2:
		await tap("attack")
		for k in 12:
			await frames(1)
			crawler_staggered = crawler_staggered or crawler.state == Dummy.State.STAGGER
	check(crawler_staggered, "два удара сбили ползуна (стойкость %.0f)" % crawler.max_poise)
	player._iframes = 0.0
	await seconds(1.0)

	print("== У ползуна нет спины")
	player.restore()
	crawler.detect_range = 0.0
	crawler._set_state(Dummy.State.PATROL)
	await seconds(0.2)
	await put(Vector3(crawler.global_position.x - crawler.facing * 1.3, 0.1, 0), crawler.facing)
	await tap("attack")
	var no_back := player.state == Player.State.ATTACK and last_step == player.weapon.combo[0]
	check(no_back, "сзади — обычный удар, не удар в спину")
	crawler.detect_range = 7.0
	await seconds(1.0)

	print("== Парирование кола и особое добивание")
	player.restore()
	await face_enemy(crawler, 1.6)
	await wait_windup(crawler, 0.08)
	await tap("block")
	await seconds(0.2)
	check(crawler.state == Dummy.State.OFF_BALANCE, "парирование: ползун «кружится» (state=%d)" % crawler.state)
	check(not crawler.spike.visible, "кол треснул и осыпался")
	crawler.health.current = 50.0
	await tap("attack")
	var special := player.state == Player.State.CRITICAL and last_step == crawler.riposte_step
	check(special, "добивание ползуна — особое: «%s»" % (last_step.display_name if last_step else "-"))
	await seconds(1.7)
	check(is_instance_valid(crawler) and crawler.state == Dummy.State.DEAD, "ползун погиб")
	check(is_instance_valid(crawler) and crawler.body_mesh.scale.y < 0.3, "растёкся лужицей и застыл (scale.y=%.2f)" % crawler.body_mesh.scale.y)

	print("== Сундук отражения на уступе")
	player.restore()
	await put(Vector3(10.5, 8.7, 0), 1.0)
	await seconds(0.3)
	var echoes_at_mirror_chest: int = game_state.echoes
	await tap("interact")
	await seconds(0.2)
	var mirror_chest := room_node("Objects/MirrorChest") as Chest
	check(game_state.echoes == echoes_at_mirror_chest + mirror_chest.reward,
		"сундук отражения открыт, отзвуки +%d" % (game_state.echoes - echoes_at_mirror_chest))

	print("== Обратно через зеркало")
	await put(Vector3(-15.5, 0.1, 0), 1.0)
	await seconds(0.3)
	await tap("interact")
	await seconds(1.0)
	check(rooms.reality == &"normal", "вернулись в обычную реальность")
	check(absf(player.global_position.x - 15.5) < 0.6, "герой у зеркала (x=%.2f)" % player.global_position.x)

	print("")
	print("== Смерть у стены: падает назад, оружие не в стене")
	player.restore()
	await put(Vector3(-23.3, 0.1, 0), -1.0)
	await seconds(0.3)
	player.health.take_damage(9999.0)
	await seconds(1.2)
	check(player.body_mesh.rotation.z > 1.4, "впереди стена — упал назад (наклон %.2f)" % player.body_mesh.rotation.z)
	var at_wall := player.arms.dropped_weapon()
	var tip_x := at_wall.global_position.x + at_wall.global_basis.y.x * 1.15 if at_wall else -99.0
	check(at_wall != null and tip_x > -24.0, "клинок не ушёл в стену (конец x=%.2f, стена -24.0)" % tip_x)
	await seconds(2.5)

	print("== Отзвук героя")
	game_state.add_echoes(100 - game_state.echoes)
	await put(Vector3(-16.0, 0.1, 0))
	await seconds(0.3)
	press("shoot")
	await seconds(0.3)
	player.health.take_damage(INF)
	release("shoot")
	await seconds(3.8)
	var hero_echoes := rooms.current_room.find_children("*", "HeroEcho", true, false)
	check(game_state.echoes == 0 and game_state.hero_echo.get("amount", 0) == 100,
		"смерть: все отзвуки — в отзвуке героя (%d)" % game_state.hero_echo.get("amount", 0))
	check(hero_echoes.size() == 1 and absf(hero_echoes[0].global_position.x + 16.0) < 0.6, "силуэт стоит на месте гибели")
	if hero_echoes.size() == 1:
		var shade := (hero_echoes[0] as HeroEcho)._silhouette
		var bow_node := shade.find_child("Bow", true, false) as Node3D
		check(bow_node != null and bow_node.visible and shade.find_child("Face", true, false) == null,
			"погиб с луком — в силуэте лук, лица нет")
	game_state.add_echoes(40)
	await put(Vector3(-17.0, 0.1, 0))
	await seconds(0.3)
	player.health.take_damage(INF)
	await seconds(3.8)
	hero_echoes = rooms.current_room.find_children("*", "HeroEcho", true, false)
	check(game_state.hero_echo.get("amount", 0) == 40 and hero_echoes.size() == 1,
		"погиб снова, не забрав: прежний отзвук пропал, в новом — новые (%d)" % game_state.hero_echo.get("amount", 0))
	if hero_echoes.size() == 1:
		await put(hero_echoes[0].global_position + Vector3(0.0, 0.1, 0.0))
		await seconds(0.2)
		await tap("interact")
		await seconds(0.8)
	check(game_state.echoes == 40 and game_state.hero_echo.is_empty(), "коснулся отзвука — отзвуки вернулись (%d)" % game_state.echoes)

	print("== Сохранение")
	var save_file := "user://smoke_test_save.sav"
	game_state.save_path = save_file
	game_state.saves_enabled = true
	game_state.add_echoes(777 - game_state.echoes)
	game_state.set_flag(&"save_probe")
	player.stats.level = 8
	player.stats.toggle_facet(Facet.by_id(&"facet_grip"), 3)
	rooms.save_now()
	game_state.add_echoes(-777)
	game_state.flags.erase(&"save_probe")
	player.stats.reset_progress()
	var extra: Dictionary = game_state.load_game()
	check(game_state.echoes == 777 and game_state.has_flag(&"save_probe"), "сохранение вернуло отзвуки и флаги мира")
	player.stats.from_dict(extra.get("stats", {}))
	check(player.stats.level == 8 and player.stats.facets.size() == 1, "сохранение вернуло уровень и грани")
	check(extra.get("room") == rooms.current_room_id and extra.get("position") is Vector3, "сохранение помнит комнату и место")
	player.stats.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	check(not game_state.has_save(), "тестовое сохранение удалено")
	game_state.saves_enabled = false

	print("== Галерея замка: вампир (§6.3), стеклянная магия: посох, Память, мана, Блик (§6.2)")
	player.restore()
	var gallery_door := room_node("Objects/DoorToGallery") as Node3D
	check(gallery_door != null, "в замке у ниши — дверь в галерею")
	await put(Vector3(gallery_door.global_position.x, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	for i in 180:
		if rooms.current_room_id == &"castle_gallery":
			break
		await frames(1)
	await seconds(0.8)
	check(rooms.current_room_id == &"castle_gallery", "дверь ведёт в галерею замка")
	var vampire := room_node("Objects/Vampire") as Vampire
	check(vampire != null and vampire.creature == CreatureKind.Kind.VAMPIRE and vampire.model != null
		and vampire.model.look == EnemyModel.VAMPIRE and vampire.unholy, "в галерее вампир: бледный манекен в плаще, нечисть")
	if vampire:
		# «Мышь» проверяется отдельно ниже: пока она не мешает остальным проверкам галереи.
		vampire.bat_first_delay = 999.0
		vampire._bat_wait = 999.0
		await face_enemy(vampire, 2.4)
		var clawed := false
		for i in 240:
			if vampire.state in [Dummy.State.WINDUP, Dummy.State.ATTACK]:
				clawed = true
				break
			await frames(1)
		check(clawed, "вампир заметил героя и бьёт когтями")
		await wait_attack_over(vampire)
		await check_vampire_bat(vampire)
	# Посох лежит у гроба за вампиром; пока герой его берёт, вампир стоит.
	var hero_stats := player.stats
	hero_stats.reset_progress()
	player.restore()
	check(hero_stats.spell_slots == 1 and hero_stats.mana_regen == 0.0 and player.mana == hero_stats.max_mana,
		"без Памяти: одна ячейка магии, мана сама не восстанавливается (%.0f маны)" % hero_stats.max_mana)
	var vampire_chase := vampire.chase_speed if vampire else 0.0
	if vampire:
		vampire.chase_speed = 0.0
	var staff_find := room_node("Objects/StaffFind") as Node3D
	check(staff_find != null, "в галерее у гроба лежит посох")
	if staff_find:
		await put(Vector3(staff_find.global_position.x, 0.1, 0.0))
		await seconds(0.2)
		await tap("interact")
		await frames(3)
	check(player.weapon != null and player.weapon.id == &"staff" and player.weapon.catalyst, "подобрал посох — катализатор в руке")
	check(&"glint" in game_state.spells and game_state.current_spell(hero_stats.spell_slots) == &"glint", "посох научил Блику: он в первой ячейке магии")
	await seconds(0.3)
	check(rooms.hud.spell_line.visible and rooms.hud.spell_line.text.contains("Блик") and rooms.hud.mana_bar.visible,
		"HUD: полоса маны и активное заклинание")
	# Память даёт больше маны, чем Интеллект; восстановление — только от Памяти.
	var mana_base := hero_stats.max_mana
	for i in 10:
		hero_stats.add_point(PlayerStats.Param.INTELLIGENCE)
	var mana_int := hero_stats.max_mana - mana_base
	check(hero_stats.mana_regen == 0.0 and hero_stats.spell_damage_mult > 1.0, "Интеллект: урон магии ×%.2f, восстановления маны не даёт" % hero_stats.spell_damage_mult)
	hero_stats.reset_progress()
	for i in 10:
		hero_stats.add_point(PlayerStats.Param.MEMORY)
	var mana_mem := hero_stats.max_mana - mana_base
	check(mana_mem > mana_int * 1.5 and hero_stats.spell_slots == 2, "Память: маны больше, чем от Интеллекта (+%.0f против +%.0f), вторая ячейка" % [mana_mem, mana_int])
	check(hero_stats.mana_regen > 0.0 and hero_stats.mana_regen < 1.0, "Память: мана восстанавливается медленно (%.2f в секунду)" % hero_stats.mana_regen)
	player.restore()
	# Блик с посоха по вампиру: вспышка дезориентирует, мана тратится; потом — добивание спереди.
	var casts: Array[GlintFlash] = []
	var on_cast := func(_spell: SpellData, effect: Node3D) -> void: casts.append(effect as GlintFlash)
	player.spell_cast.connect(on_cast)
	if vampire:
		vampire.chase_speed = vampire_chase
		vampire._blind_count = 0
		await face_enemy(vampire, 3.0)
		var mana_before := player.mana
		await tap("attack")
		await frames(2)
		check(player.state == Player.State.CAST, "удар посохом — заклинание")
		await seconds(0.5)
		check(casts.size() == 1 and vampire in casts[0].blinded and vampire.state == Dummy.State.BLINDED and vampire.can_be_riposted(),
			"Блик дезориентировал вампира: открыт спереди")
		var glint_cost := SpellData.by_id(&"glint").mana_cost
		check(is_equal_approx(mana_before - player.mana, glint_cost), "Блик стоит %.0f маны" % glint_cost)
		await put(Vector3(vampire.global_position.x + vampire.facing * 1.2, 0.1, 0.0), -vampire.facing)
		await seconds(0.1)
		var mana_low := player.mana
		await tap("attack")
		check(player.state == Player.State.CRITICAL, "добивание дезориентированного вампира спереди")
		await seconds(2.5)
		check(player.mana > mana_low, "мана понемногу возвращается (%.1f → %.1f)" % [mana_low, player.mana])
	player.spell_cast.disconnect(on_cast)
	# Нет маны — посох бьёт сам, полоса маны мигает.
	var shorted := [false]
	var on_short := func() -> void: shorted[0] = true
	player.mana_short.connect(on_short)
	player.restore()
	player.mana = 0.0
	await put(Vector3(-10.0, 0.1, 0.0), -1.0)
	await seconds(0.2)
	await tap("attack")
	await frames(2)
	check(player.state == Player.State.ATTACK and shorted[0], "нет маны — посох бьёт сам, полоса маны мигает")
	player.mana_short.disconnect(on_short)
	await seconds(0.8)
	player.restore()
	check(player.mana == hero_stats.max_mana, "отдых (как у осколка) — мана полная")
	# Посох и Блик — только в этой проверке: дальше тест идёт как раньше.
	hero_stats.reset_progress()
	player.equip(&"sword")
	game_state.items.erase(&"staff")
	game_state.spells.clear()
	game_state.spell_slots = [&"", &"", &"", &"", &""]
	game_state.flags.erase(&"got_staff")
	Events.spells_changed.emit()
	player.restore()
	await put(room_node("Objects/DoorBack").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	for i in 180:
		if rooms.current_room_id == &"room_001":
			break
		await frames(1)
	await seconds(0.8)
	check(rooms.current_room_id == &"room_001", "из галереи — обратно в замок")
	player.restore()

	print("== Деревня: хижина")
	player.restore()
	game_state.flags.erase(&"intro_done")
	game_state.set_flag(&"dream_seen")
	player.equip(&"")
	game_state.flags.erase(&"has_bow")
	await rooms.travel(&"village_hut", ^"Spawns/PlayerStart")
	await frames(3)
	check(rooms.current_room_id == &"village_hut" and player.lying and player.frozen, "герой лежит на кровати")
	await seconds(2.5)
	check(not player.lying and not player.frozen, "проснулся и встал")
	await tap("attack")
	await tap("shoot")
	check(player.state == Player.State.MOVE, "без оружия ни удара, ни лука")
	await seconds(1.5)
	await put(room_node("Spawns/FromStreet").global_position)
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"village_street", "дверь вывела на улицу")

	print("== Деревня: смерть до первого осколка")
	var saved_checkpoint := [game_state.checkpoint_room, game_state.checkpoint_reality, game_state.checkpoint_path]
	game_state.checkpoint_room = &"village_hut"
	game_state.checkpoint_reality = &"normal"
	game_state.checkpoint_path = ^"Spawns/PlayerStart"
	player.health.take_damage(INF)
	for i in 600:
		await frames(1)
		if rooms.current_room_id == &"village_hut" and not player.is_dead() and not rooms._busy:
			break
	check(rooms.current_room_id == &"village_hut", "до осколка смерть возвращает в хижину")
	check(absf(player.global_position.x - room_node("Spawns/PlayerStart").global_position.x) < 0.5, "герой снова у кровати")
	check(not player.lying and not player.frozen, "заставка не повторяется")
	game_state.checkpoint_room = saved_checkpoint[0]
	game_state.checkpoint_reality = saved_checkpoint[1]
	game_state.checkpoint_path = saved_checkpoint[2]
	await rooms.travel(&"village_street", ^"Spawns/FromHut")
	await seconds(0.3)

	print("== Деревня: улица")
	check(player.is_on_floor() or player.velocity.y <= 0.0, "герой стоит на тропе")
	await put(Vector3(26.5, 0.1, 0))
	await seconds(0.2)
	await tap("interact")
	await seconds(0.7)
	check(rooms.current_room_id == &"village_street", "без палки в дом не войти")
	check(messages.has("«Голыми руками не помочь…»"), "на выходе из хижины: голыми руками не помочь")
	check(messages[-1].contains("поленница"), "у запертого дома — намёк на поленницу")
	var log_pickup := room_node("Objects/Stick") as ItemPickup
	check(log_pickup.global_position.x < room_node("Objects/DoorToHut").global_position.x + 4.0, "брусок у хижины, у поленницы")
	await put(log_pickup.global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.3)
	await tap("interact")
	await frames(3)
	check(player.weapon != null and player.weapon.id == &"stick" and game_state.has_flag(&"got_stick"), "взял брусок")
	check(messages[-1] == "«Всё равно сгорит. А так мне будет спокойнее.»", "реплика, когда взял брусок")
	var popup := rooms.hud.popup
	check(popup.visible and popup.shown == &"stick" and popup._name.text == "Брусок", "окно находки: значок и «Брусок»")
	popup.blocks_interact = true
	var said := messages.size()
	await tap("interact")
	await frames(2)
	check(not popup.visible and messages.size() == said, "«ОК» закрыл окно и ничего не взял")
	popup.blocks_interact = false
	check(player.weapon.combo.size() == 3 and player.weapon.type == &"sword", "палка бьёт как меч")
	check(player._blade_damage() < player.stats.sword_damage, "палка слабее меча")
	await put(Vector3(-13.0, 1.4, 0))
	press("move_right")
	await seconds(1.2)
	release("move_right")
	check(player.global_position.x > -9.0 and player.global_position.y < 1.0, "тропа спускается к площади (%.1f, %.1f)" % [player.global_position.x, player.global_position.y])
	await put(Vector3(26.5, 0.1, 0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"village_house", "вошёл в дом")

	print("== Деревня: дом")
	await seconds(0.1)
	await put(room_node("Spawns/FromExit").global_position)
	await seconds(0.2)
	await tap("interact")
	await seconds(0.7)
	check(rooms.current_room_id == &"village_house", "пока в доме кто-то есть, выход закрыт")
	var rat_a := room_node("Objects/RatA") as Dummy
	check(rat_a != null and room_node("Objects/RatB") != null and room_node("Objects/Bat") != null, "две крысы и летучая мышь")
	var mastery_before: float = game_state.mastery_xp(&"sword")
	player.restore()
	await put(rat_a.global_position + Vector3(-1.1, 0.1, 0), 1.0)
	rat_a.detect_range = 0.0
	rat_a.patrol_speed = 0.0
	var swings := 0
	while is_instance_valid(rat_a) and rat_a.state != Dummy.State.DEAD and swings < 12:
		await tap("attack")
		await seconds(0.45)
		player.global_position.x = rat_a.global_position.x - 1.1 if is_instance_valid(rat_a) else player.global_position.x
		swings += 1
	check(swings < 12, "палка убила крысу за %d ударов" % swings)
	check(game_state.mastery_xp(&"sword") > mastery_before, "убийство пошло в мастерство меча")
	await seconds(1.4)
	var rat_b := room_node("Objects/RatB") as Dummy
	rat_b.health.take_damage(INF)
	await seconds(0.2)
	await put(room_node("Objects/Ladder").global_position + Vector3(0.0, 0.1, 0))
	await seconds(0.1)
	press("move_up")
	await seconds(0.2)
	check(player.state == Player.State.LADDER, "лезет по лестнице")
	await seconds(1.6)
	release("move_up")
	await seconds(0.6)
	check(player.global_position.y > 3.8 and player.is_on_floor(), "поднялся на чердак (y=%.2f)" % player.global_position.y)
	var bat := room_node("Objects/Bat") as Bat
	player.restore()
	await put(Vector3(2.0, 4.1, 0), -1.0)
	await seconds(0.2)
	check(bat._awake, "летучая мышь проснулась")
	var hp_bat := player.health.current
	var dove := false
	for i in 300:
		await frames(1)
		dove = dove or bat.state == Dummy.State.ATTACK
		if player.health.current < hp_bat:
			break
	check(dove and player.health.current < hp_bat, "пикирует и кусает (hp %.0f → %.0f)" % [hp_bat, player.health.current])
	bat.health.take_damage(INF)
	await frames(2)
	check(bat.state == Dummy.State.DEAD, "летучая мышь сбита")
	await seconds(1.5)
	await put(room_node("Spawns/FromExit").global_position)
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"village_square", "дом пуст — дверь вывела на площадь")
	check(game_state.killed_in(&"village_house/normal").size() == 3, "мир помнит убитых в этой комнате")

	print("== Площадь: оборотень")
	check(room_node("Burning") != null and room_node("AfterFire") == null, "деревня горит, осколка на площади пока нет")
	check((room_node("Objects/DoorToChapel") as RoomDoor).is_locked(), "дальше не пройти, пока горит")
	var wolf := room_node("Objects/Werewolf") as Werewolf
	check(wolf != null and wolf.state == Dummy.State.DORMANT and wolf.non_lethal, "зверь склонился над жертвой, удары не смертельны")
	player.restore()
	await put(Vector3(wolf.global_position.x - 7.0, 0.1, 0), 1.0)
	await seconds(1.2)
	check(wolf.engaged and wolf.state != Dummy.State.DORMANT, "зверь услышал героя и бросается")
	check(rooms.hud.boss_bar != null, "у оборотня полоса здоровья")
	check(wolf.body_mesh.global_position.z + 0.4 < -0.38, "модель оборотня за героем")
	var wolf_moves := {}
	var wolf_hit := false
	for i in 2400:
		await frames(1)
		if player.health.current < 60.0:
			wolf_hit = true
			player.health.current = 100.0
		if wolf.state == Dummy.State.ATTACK:
			wolf_moves[wolf.move] = true
		if wolf.state == Dummy.State.CHASE:
			var far_left := wolf_moves.size() < 2 or not wolf_moves.has(Werewolf.Move.LEAP) or not wolf_moves.has(Werewolf.Move.RUSH)
			var wolf_gap := (8.0 if wolf.global_position.x < 0.0 else -8.0) if far_left else 1.6 * wolf.facing
			player.global_position.x = wolf.global_position.x + wolf_gap
		# Ударов пять (с финтом и воем): ждём именно когти, рывок и прыжок, а не любые три.
		if wolf_hit and wolf_moves.has(Werewolf.Move.CLAW) and wolf_moves.has(Werewolf.Move.RUSH) and wolf_moves.has(Werewolf.Move.LEAP):
			break
	check(wolf_moves.has(Werewolf.Move.CLAW), "оборотень бьёт когтями")
	check(wolf_moves.has(Werewolf.Move.RUSH), "оборотень бросается рывком")
	check(wolf_moves.has(Werewolf.Move.LEAP), "оборотень прыгает")
	check(wolf_hit, "удары оборотня достают героя")
	# Поражение: героя не убить, зов уводит зверя, герой приходит в себя, когда огонь стих.
	player.restore()
	for i in 3600:
		await frames(1)
		if not wolf.is_inside_tree() or wolf.in_scene or wolf._called:
			break
		player.global_position.x = wolf.global_position.x + 1.5 * wolf.facing
	check(wolf.in_scene and player.frozen and rooms.hud._bars.size() == 2, "бой окончен — катсцена: полосы кадра, герой замер")
	var hp_maul := player.health.current
	for i in 600:
		await frames(1)
		if wolf._called:
			break
	check(absf(wolf.global_position.x - player.global_position.x) < 1.2, "зверь с прыжка встал над героем")
	check(not player.is_dead() and player.lying and player.frozen and player.health.current <= maxf(hp_maul - 4.0, 1.0),
		"мальчишку растерзали, но он жив (%.0f → %.0f)" % [hp_maul, player.health.current])
	check(rooms.hud._say_label.text.contains("зов"), "из леса — зов, зверь замирает")
	for i in 900:
		await frames(1)
		if game_state.has_flag(&"fire_out") and not player.lying:
			break
	check(game_state.has_flag(&"fire_out"), "огонь стих")
	check(not player.lying and not player.frozen, "герой очнулся и встал")
	check(not game_state.has_flag(&"wolf_scarred"), "без раны — отметины нет")
	check(player.health.current == player.health.max_health, "очнулся с полным здоровьем")
	check(rooms.current_room_id == &"village_square" and room_node("Burning") == null, "пожара больше нет")
	check(room_node("Objects/Werewolf") == null or room_node("Objects/Werewolf").is_queued_for_deletion(), "зверь ушёл")
	check(game_state.checkpoint_room == &"village_square", "возрождение теперь на площади")
	check(rooms.current_room.is_burning() == false, "у площади обычное освещение")
	# Другой исход: мальчишка сумел ранить зверя.
	game_state.flags.erase(&"fire_out")
	await rooms.travel(&"village_square", ^"Spawns/FromHouse")
	await seconds(0.8)
	wolf = room_node("Objects/Werewolf") as Werewolf
	check(wolf != null and room_node("Burning") != null, "снова пожар и зверь (для второго исхода)")
	await put(Vector3(wolf.global_position.x - 6.0, 0.1, 0), 1.0)
	await seconds(1.1)
	wolf.health.take_damage(wolf.health.max_health * 0.55)
	await frames(2)
	check(game_state.has_flag(&"wolf_scarred"), "рана оставляет отметину")
	for i in 900:
		await frames(1)
		if game_state.has_flag(&"fire_out") and not player.lying:
			break
	check(game_state.has_flag(&"fire_out") and not player.lying, "после раны зверь тоже уходит")
	await seconds(0.3)
	await rooms.travel(&"village_street", ^"Spawns/FromHouse")
	await seconds(0.3)
	check(room_node("Burning") == null and room_node("AfterFire") != null, "улица после пожара")
	await rooms.travel(&"village_square", ^"Spawns/FromChapel")
	await seconds(0.3)
	await put(room_node("AfterFire/MirrorShard").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.2)
	rooms.level_menu.close()
	check(game_state.has_flag(&"shard_village_square"), "осколок на площади активирован")

	print("== Двор часовни")
	await put(room_node("Objects/DoorToChapel").global_position + Vector3(-0.5, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"chapel_yard", "с площади — к часовне")
	game_state.flags.erase(&"got_sword")
	player.equip(&"stick")
	await seconds(0.1)
	await put(room_node("Objects/Smith").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(player.weapon.id == &"sword" and game_state.has_flag(&"got_sword"), "кузнец отдал меч")
	var echoes_yard: int = game_state.echoes
	game_state.add_echoes(300 - game_state.echoes)
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(messages[-1].contains("гоплон") and messages[-1].contains("250") and game_state.item_count(GameState.SHIELD_ITEM) == 0,
		"кузнец предлагает щит за 250 отзвуков")
	await tap("interact")
	await frames(3)
	check(game_state.item_count(GameState.SHIELD_ITEM) == 1 and game_state.echoes == 50 and player.shield_in_hand(),
		"купил щит — он в руке (%d отзвуков)" % game_state.echoes)
	await tap("interact")
	await frames(3)
	check((room_node("Objects/Smith") as Npc)._next == 1, "дальше кузнец рассказывает")
	game_state.items.erase(GameState.SHIELD_ITEM)
	player.equip(&"sword")
	game_state.add_echoes(echoes_yard - game_state.echoes)
	for i in 3:
		await tap("interact")
		await frames(2)
	var spoken := rooms.hud.find_children("*", "Label", true, false).filter(
		func(label: Label) -> bool: return label.text.begins_with("Кузнец:") and label.modulate.a > 0.0)
	check(spoken.size() == 1 and rooms.hud._say_label.text.begins_with("Кузнец:"), "реплики не ложатся друг на друга: видна одна (%d)" % spoken.size())
	var herbalist_here := room_node("Objects/Herbalist")
	check((herbalist_here == null or herbalist_here.is_queued_for_deletion()) and room_node("Objects/Glassblower") != null,
		"Травница пропала (её похитили), стекольщик на месте")
	await put(room_node("Objects/MirrorShard").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.2)
	rooms.level_menu.close()
	check(game_state.has_flag(&"shard_chapel_yard"), "осколок у часовни активирован")
	await seconds(0.2)
	await put(room_node("Objects/DoorToChapel").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"chapel", "вошёл в часовню")

	print("== Часовня и Главное Зеркало")
	var mirror := room_node("Objects/MainMirror") as MainMirror
	check(mirror.is_locked(), "Главное Зеркало закрыто")
	check(mirror.lit_panes() == 2 and mirror.get_node_or_null("Pane4") != null, "открыты два куска из пяти")
	await put(mirror.global_position + Vector3(0.5, 0.1, 0.0))
	await seconds(0.6)
	check(mirror._reflection != null, "в зеркале отражение героя")
	await tap("interact")
	await seconds(0.7)
	check(rooms.current_room_id == &"chapel", "зеркало молчит")
	# Гнилой пол балкона проламывается ударом вниз, под ним тайник.
	var stash := room_node("Objects/StashFloor") as GlassSurface
	await put(Vector3(10.5, 6.5, 0.0), 1.0)
	press("move_down")
	await tap("attack")
	await seconds(0.9)
	release_all()
	check(stash._broken, "удар вниз проломил пол")
	check(player.global_position.y < 1.0, "герой упал в тайник")
	await put(room_node("Objects/StashChest").global_position + Vector3(0.0, 0.1, 1.2))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.has_flag(&"chapel_stash"), "сундук в тайнике открыт")
	await put(room_node("Objects/StashLadder").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.1)
	press("move_up")
	await seconds(2.0)
	release("move_up")
	await seconds(0.5)
	check(player.global_position.y > 4.0, "из тайника вылез по лестнице (y=%.2f)" % player.global_position.y)
	await rooms.travel(&"chapel_yard", ^"Spawns/FromChapel")
	await seconds(0.3)
	await put(room_node("Objects/DoorToForest").global_position + Vector3(-0.5, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"cemetery_gate", "от часовни — к кладбищу")

	print("== Лес: ворота кладбища")
	check(room_node("Decor/LanternLight") != null, "фонарь на колонне — последний человеческий огонь")
	player.restore()
	await put(room_node("Objects/RootClimb").global_position + Vector3(0.0, 0.1, 0.0), 1.0)
	press("move_up")
	await seconds(2.2)
	release("move_up")
	await seconds(0.5)
	check(player.global_position.y > 4.0, "по корню — на пост могильщика (y=%.2f)" % player.global_position.y)
	var hp_trap := player.health.current
	var plank := room_node("Objects/RottenPlank") as GlassSurface
	await put(Vector3(1.0, 4.5, 0.0), 1.0)
	await seconds(1.3)
	check(plank._broken and player.global_position.y < 4.0, "гнилая доска провалилась")
	check(player.health.current < hp_trap and not player.is_dead(), "колья ранят, но не убивают (%.0f → %.0f)" % [hp_trap, player.health.current])
	await put(room_node("Objects/PostChest").global_position + Vector3(0.0, 0.1, 0.8))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.has_flag(&"cem_gate_chest"), "сундук на посту открыт")
	await rooms.travel(&"cemetery", ^"Spawns/FromGate")
	await seconds(0.3)

	print("== Лес: кладбище и мародёры")
	var heavy := room_node("Objects/RobberHeavy") as Bandit
	var knife := room_node("Objects/RobberKnife") as Bandit
	check(heavy != null and knife != null and not heavy.visible and heavy.state == Dummy.State.DORMANT, "мародёры в склепе")
	check((room_node("Objects/SealedCryptDoor") as RoomDoor).is_locked(), "нижний склеп запечатан")
	player.restore()
	await put(Vector3(3.2, 2.2, 0), 1.0)
	await seconds(2.2)
	check(heavy.visible and heavy.state != Dummy.State.DORMANT and knife.state != Dummy.State.DORMANT, "дверь склепа распахнулась — мародёры напали")
	check(absf(heavy.global_position.z) < 0.3 and absf(knife.global_position.z) < 0.3, "выбежали в плоскость боя")
	var robbers_hit := false
	var hp_rob := player.health.current
	for i in 360:
		await frames(1)
		if player.health.current < hp_rob:
			robbers_hit = true
			player.health.current = player.health.max_health
		hp_rob = player.health.current
		if robbers_hit:
			break
	check(robbers_hit, "мародёры бьют героя")
	check(heavy._move_i > 0 and heavy._moves.size() == 3, "мародёр бьёт ударами молота — подсвечником (%d)" % heavy._move_i)
	heavy.health.take_damage(INF)
	knife.health.take_damage(INF)
	await seconds(1.0)
	var candlestick := room_node("Objects/CandlestickDrop") as ItemPickup
	check(candlestick != null, "мародёр выронил подсвечник")
	if candlestick:
		await put(candlestick.global_position + Vector3(0.0, 0.1, 0.0))
		await seconds(0.2)
		await tap("interact")
		await frames(3)
	check(player.weapon != null and player.weapon.id == &"candlestick" and game_state.has_flag(&"got_candlestick"), "подобрал подсвечник")
	player.equip(&"sword")
	rooms.level_menu._player = player
	rooms.level_menu.switch_second()
	check(game_state.second_weapon_id != &"" and game_state.second_weapon_id != game_state.weapon_id, "набор II: второе оружие с собой (%s)" % game_state.second_weapon_id)
	check(player.equip_weight() > WeaponData.by_id(&"sword").weight, "второй набор весит")
	game_state.second_weapon_id = &""
	await put(room_node("Objects/MirrorShard").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.2)
	rooms.level_menu.close()
	check(game_state.has_flag(&"shard_cemetery"), "осколок на кладбище")
	await rooms.travel(&"forest_wall", ^"Spawns/FromCemetery")
	await seconds(0.3)

	print("== Лес: стена леса")
	player.restore()
	await put(room_node("Objects/Vines").global_position + Vector3(0.0, 0.1, 0.0), 1.0)
	press("move_up")
	await seconds(3.0)
	release("move_up")
	await seconds(0.5)
	check(player.global_position.y > 5.5, "по лианам — на верхний маршрут (y=%.2f)" % player.global_position.y)
	check(room_node("Objects/ScoutLetter") is Note, "письмо разведчика")
	await put(room_node("Objects/ScoutSupplies").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.has_flag(&"scout_supplies"), "припасы разведчика взяты")
	await rooms.travel(&"fallen_giant", ^"Spawns/FromWall")
	await seconds(0.3)

	print("== Лес: поваленный гигант")
	await put(Vector3(-15.0, 0.6, 0), 1.0)
	press("move_right")
	await seconds(2.2)
	release("move_right")
	check(player.global_position.y > 2.5, "по стволу вверх (y=%.2f)" % player.global_position.y)
	check(room_node("Objects/BanditNote") is Note, "записка разбойников на столе")
	await put(room_node("Objects/Herbalist").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.has_flag(&"herbalist_rescued"), "Травница развязана")
	await put(room_node("Objects/MirrorShard").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.2)
	rooms.level_menu.close()
	check(game_state.has_flag(&"shard_fallen_giant"), "осколок у хижины")
	player.restore()
	var hp_ravine := player.health.current
	await put(Vector3(4.8, 6.0, 0), 1.0)
	await seconds(2.4)
	check(player.global_position.y < -11.0 and not player.is_dead() and player.health.current < hp_ravine * 0.8,
		"сорвался в пропасть: огромный урон, но жив (%.0f → %.0f)" % [hp_ravine, player.health.current])
	var ravine_ladder := room_node("Objects/RavineLadder") as Ladder
	player.hurtbox.invulnerable = true
	await put(ravine_ladder.global_position + Vector3(0.0, 0.1, 0.0), 1.0)
	press("move_up")
	await seconds(ravine_ladder.height / player.stats.climb_speed + 1.2)
	release("move_up")
	await seconds(0.6)
	player.hurtbox.invulnerable = false
	check(player.is_on_floor() and player.global_position.y > 3.5, "из пропасти — по лестнице в трещине на ствол (y=%.2f)" % player.global_position.y)
	# Колья на дне убивают; отзвук героя остаётся до них, на безопасном месте.
	var ravine_spikes := room_node("Objects/RavineSpikes") as Spikes
	ravine_spikes.wound_chance = 1.0
	for rat in nodes_where(rooms.current_room, func(n: Node) -> bool: return n is Rat):
		rat.process_mode = Node.PROCESS_MODE_DISABLED
	game_state.add_echoes(200)
	var spike_x := ravine_spikes.global_position.x
	await put(Vector3(spike_x - 3.2, -13.9, 0), 1.0)
	await seconds(0.3)
	player.health.current = 30.0
	var spike_died := false
	var spike_bled := false
	for i in 8:
		await put(Vector3(spike_x, -12.6, 0), 1.0)
		await seconds(0.3)
		spike_bled = spike_bled or player.wound_t > 0.0
		if player.is_dead():
			spike_died = true
			break
		await put(Vector3(spike_x - 3.2, -13.9, 0), 1.0)
		await seconds(0.15)
	check(spike_bled, "колья пускают кровь")
	check(spike_died, "колья на дне пропасти убивают")
	check(not game_state.hero_echo.is_empty() and game_state.hero_echo["position"].x < spike_x - 2.0,
		"отзвук героя остался до кольев (x=%.1f, колья %.1f)" % [game_state.hero_echo.get("position", Vector3.ZERO).x, spike_x])
	for i in 600:
		await frames(1)
		if not player.is_dead() and not rooms._busy:
			break
	check(not player.is_dead() and rooms.current_room_id == &"fallen_giant" and player.global_position.y > 3.0,
		"возродился у осколка на стволе")
	await rooms.travel(&"root_maze", ^"Spawns/FromGiant")
	await seconds(0.3)

	print("== Лес: корневой лабиринт")
	var wraith := room_node("Objects/WraithA") as FogWraith
	await frames(3)
	check(wraith != null and wraith.body_color.a < 0.2, "призрак в тумане едва виден (%.2f)" % wraith.body_color.a)
	check(nodes_where(rooms.current_room, func(n: Node) -> bool: return n is FogWraith).size() >= 4, "летунов в тумане четверо")
	await put(Vector3(-5.0, 8.1, 0), 1.0)
	await seconds(0.4)
	var abyss_bat := room_node("Objects/AbyssBatA") as Bat
	check(not abyss_bat._awake, "летуны бездны спят, пока герой наверху")
	player.restore()
	var hp_root := player.health.current
	await put(Vector3(-0.5, 8.4, 0), 1.0)
	await seconds(2.6)
	check((room_node("Objects/SawnRoot0") as GlassSurface)._broken and player.global_position.y < -7.0, "подрубленный корень рухнул")
	check(not player.is_dead() and player.health.current < hp_root, "падение на дно: больно, но жив (%.0f → %.0f)" % [hp_root, player.health.current])
	await seconds(0.4)
	check(abyss_bat._awake or (room_node("Objects/AbyssBatB") as Bat)._awake, "внизу на героя бросаются летуны")
	var abyss_ladder := room_node("Objects/AbyssLadder") as Ladder
	player.hurtbox.invulnerable = true
	await put(abyss_ladder.global_position + Vector3(0.0, 0.1, 0.0), -1.0)
	press("move_up")
	await seconds(abyss_ladder.height / player.stats.climb_speed + 1.2)
	release("move_up")
	await seconds(0.6)
	player.hurtbox.invulnerable = false
	check(player.is_on_floor() and player.global_position.y > 2.7, "из бездны — по лестнице на нижнюю тропу (y=%.2f)" % player.global_position.y)
	await put(room_node("Objects/RootCache").global_position + Vector3(0.0, 0.1, 1.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	player.restore()
	check(game_state.has_flag(&"root_cache") and game_state.item_count(&"flask_vessel") == 1 and player.max_flasks() == 2,
		"тайник в корне: второй глоток зелья")
	var draw_plain := player._bow_draw_time()
	player.hurtbox.invulnerable = true
	await put(room_node("Objects/BowHunter").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	player.hurtbox.invulnerable = false
	check(game_state.bow_id == &"bow_hunter" and game_state.has_flag(&"has_bow") and player._bow_draw_time() < draw_plain,
		"наверху лабиринта — охотничий лук: натягивается быстрее (%.2f → %.2f с)" % [draw_plain, player._bow_draw_time()])
	await rooms.travel(&"swamp", ^"Spawns/FromMaze")
	await seconds(0.3)

	print("== Лес: болото")
	await put(Vector3(-27.0, 0.1, 0), 1.0)
	press("move_right")
	await seconds(0.4)
	release("move_right")
	var clean_run := player.global_position.x + 27.0
	await put(Vector3(-18.0, 0.1, 0), 1.0)
	await frames(3)
	check(player.in_mud(), "в грязи")
	await seconds(0.3)
	check(player.has_effect(&"mud") and rooms.hud.effects_row.has_node("mud"), "в грязи — дебафф со значком под полосами")
	press("move_right")
	await seconds(0.4)
	release("move_right")
	var mud_run := player.global_position.x + 18.0
	check(mud_run < clean_run * 0.75, "грязь замедляет (%.1f м против %.1f)" % [mud_run, clean_run])
	await put(Vector3(-18.0, 0.1, 0), 1.0)
	player._combat_t = 0.0
	player.stamina = player.stats.max_stamina
	await tap("roll")
	await frames(3)
	check(player.stamina <= player.stats.max_stamina - player.stats.roll_cost * 1.7, "в грязи кувырок в бою дороже")
	player._combat_t = 99.0
	await seconds(0.6)
	var knight := room_node("Objects/DrownedKnight") as DrownedKnight
	check(knight.state == Dummy.State.DORMANT and knight.visual.position.y < -1.0, "утопленник лежит под водой")
	player.restore()
	await put(Vector3(knight.global_position.x - 4.5, 0.1, 0), 1.0)
	await seconds(1.8)
	check(knight._risen and knight.state != Dummy.State.DORMANT, "утопленник поднялся из воды")
	var probe := Hitbox.new()
	rooms.current_room.add_child(probe)
	probe.damage = 20.0
	probe.global_position = knight.global_position + Vector3(knight.facing * 1.0, 1.0, 0.0)
	knight._set_state(Dummy.State.CHASE)
	var hp_knight := knight.health.current
	knight._on_hurt(probe)
	check(hp_knight - knight.health.current < 5.0, "щит держит удар спереди (−%.1f)" % (hp_knight - knight.health.current))
	check(knight._guard_lock > 0.0 and knight.state == Dummy.State.CHASE, "удар в щит отталкивает — в ответ бьёт не сразу")
	for i in DrownedKnight.GUARD_BREAK_HITS - 1:
		knight._on_hurt(probe)
	check(knight.state == Dummy.State.OFF_BALANCE and knight.can_be_riposted(), "удары в щит подряд — защита пробита, можно добить")
	knight._set_state(Dummy.State.RECOVER)
	hp_knight = knight.health.current
	knight._on_hurt(probe)
	check(hp_knight - knight.health.current > 15.0, "в откате щит опущен — удар проходит (−%.1f)" % (hp_knight - knight.health.current))
	knight._set_state(Dummy.State.CHASE)
	probe.heavy = true
	hp_knight = knight.health.current
	knight._on_hurt(probe)
	check(hp_knight - knight.health.current > 15.0, "тяжёлый удар пробивает щит (−%.1f)" % (hp_knight - knight.health.current))
	probe.queue_free()
	knight.health.take_damage(INF)
	await seconds(0.6)
	await rooms.travel(&"cursed_village", ^"Spawns/FromSwamp")
	await seconds(0.3)

	print("== Лес: мёртвая деревня и Безмолвный Кузнец")
	await put(room_node("Objects/MirrorShard").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.2)
	rooms.level_menu.close()
	check(game_state.has_flag(&"shard_cursed_village"), "осколок у входа в деревню")
	var smith := room_node("Objects/Blacksmith") as Blacksmith
	var arena := room_node("Objects/Arena") as BossArena
	check(smith != null and smith.seated and smith.state == Dummy.State.DORMANT and smith.health.max_health == 800.0, "Кузнец сидит на камне среди черепов")
	check(not arena.is_closed(), "пока тихо — тумана нет")
	player.restore()
	await put(Vector3(smith.global_position.x - 6.0, 0.1, 0), 1.0)
	for i in 480:
		await frames(1)
		if smith._engaged:
			break
	check(smith._engaged and arena.is_closed() and smith.state != Dummy.State.DORMANT, "дух вселился, Кузнец встал, поднялись туманные стены")
	check(rooms.hud.boss_bar != null, "у босса полоса здоровья")
	await put(Vector3(arena.left_x + 1.5, 0.1, 0), -1.0)
	press("move_left")
	await seconds(0.8)
	release_all()
	check(player.global_position.x > arena.left_x - 0.2, "сквозь туманную стену не выйти")
	player.restore()
	await put(Vector3(smith.global_position.x - 2.2, 0.1, 0), 1.0)
	smith.facing = -1.0
	var saw_slam := false
	var hammer_head := smith.hammer_head as Node3D
	var hammer_top := 0.0
	var smith_hit := false
	var hp_frame := player.health.current
	for i in 1500:
		await frames(1)
		smith_hit = smith_hit or player.health.current < hp_frame
		player.health.current = maxf(player.health.current, 50.0)
		hp_frame = player.health.current
		var slamming := smith.state == Dummy.State.WINDUP and smith._blow in [Blacksmith.Blow.SLAM, Blacksmith.Blow.SLAM_HELD]
		saw_slam = saw_slam or slamming
		if slamming:
			hammer_top = maxf(hammer_top, hammer_head.global_position.y - smith.global_position.y)
		if saw_slam and smith.state == Dummy.State.RECOVER and smith._chain.size() <= 1:
			break
	check(saw_slam, "Кузнец заносит молот сверху")
	check(smith_hit, "удар Кузнеца достаёт героя")
	check(hammer_top > 3.0, "молот поднят над головой (%.1f м)" % hammer_top)
	await seconds(0.25)
	check(hammer_head.global_position.y - smith.global_position.y < 1.0, "молот упал до земли (%.1f м)" % (hammer_head.global_position.y - smith.global_position.y))
	check(smith.recover_time >= smith.slam_stuck * 0.7, "после удара сверху молот застревает в камне (%.1f с)" % smith.recover_time)
	var saw_drag := false
	for i in 600:
		await frames(1)
		player.health.current = maxf(player.health.current, 50.0)
		if smith.state == Dummy.State.CHASE:
			player.global_position.x = smith.global_position.x + (6.0 if smith.global_position.x < 4.0 else -6.0)
		if smith.state == Dummy.State.ATTACK and smith._blow == Blacksmith.Blow.DRAG:
			saw_drag = true
			break
	check(saw_drag, "волок: тащит молот и бьёт")
	check(smith.hurt_voice == &"" and smith.death_voice == &"", "Кузнец безмолвен")
	check(not smith.backstab_allowed, "у Кузнеца нет добивания в спину: перекат за спину его не даёт")
	await seconds(1.5)
	# Герой всегда перед Кузнецом: модель и молот не перекрывают его, куда бы тот ни смотрел.
	for side in 2:
		check(smith.body_mesh.global_position.z + 0.55 < -0.38 and hammer_head.global_position.z + 0.35 < 0.0, "модель и молот за героем (facing %.0f)" % smith.facing)
		smith.facing = -smith.facing
		await frames(2)
	# Перекат сквозь босса: без переката он твёрдый, из переката выходим за спиной.
	var smith_home := Vector3(4.0, smith.global_position.y, 0.0)
	smith.global_position = smith_home
	var smith_reach: float = smith.body_half_width() + 0.3
	smith.set_physics_process(false)
	await put(Vector3(smith_home.x - 1.5, 0.1, 0), 1.0)
	press("move_right")
	await seconds(0.6)
	release_all()
	check(player.global_position.x < smith_home.x - smith_reach, "шагом сквозь Кузнеца не пройти")
	player._combat_t = 99.0
	await tap("roll")
	await seconds(0.6)
	check(player.global_position.x > smith_home.x + smith_reach, "перекат выводит за спину Кузнеца")
	check(player._rolled_through.is_empty(), "после переката босс снова твёрдый")
	await put(Vector3(smith_home.x - 3.4, 0.1, 0), 1.0)
	await tap("roll")
	await seconds(0.9)
	check(player.global_position.x > smith_home.x + smith_reach, "перекат не заканчивается внутри босса")
	check(player.state == Player.State.MOVE, "перекат закончился (%s)" % player.state)
	# Босс у туманной стены: упёрлись — выходим обратно, а не застреваем.
	var smith_wall := Vector3(arena.left_x + 0.9, smith_home.y, 0.0)
	smith.global_position = smith_wall
	await put(Vector3(smith_wall.x + 1.3, 0.1, 0), -1.0)
	await tap("roll")
	await seconds(1.0)
	check(absf(player.global_position.x - smith_wall.x) >= smith_reach, "у стены из босса выходим обратно")
	check(player.state == Player.State.MOVE and player._rolled_through.is_empty(), "у стены перекат закончился")
	smith.global_position = smith_home
	smith.set_physics_process(true)
	# Сбитая стойкость — на колено, можно добить.
	await put(Vector3(smith_home.x - 2.5, 0.1, 0), 1.0)
	var boss_probe := Hitbox.new()
	rooms.current_room.add_child(boss_probe)
	boss_probe.global_position = smith.global_position + Vector3(-1.0, 1.0, 0.0)
	boss_probe.damage = 1.0
	boss_probe.poise_damage = smith.max_poise + 10.0
	smith._on_hurt(boss_probe)
	check(smith.state == Dummy.State.OFF_BALANCE and smith.can_be_riposted(), "сбитая стойкость: Кузнец на колене, можно добить")
	await seconds(2.6)
	# Вторая фаза.
	boss_probe.poise_damage = 0.0
	boss_probe.damage = smith.health.current - smith.health.max_health * 0.5
	smith._on_hurt(boss_probe)
	check(smith.phase == 2 and smith.hurtbox.invulnerable, "на половине здоровья — вторая фаза, в переходе неуязвим")
	for i in 600:
		await frames(1)
		player.health.current = maxf(player.health.current, 50.0)
		if not smith._scene_running:
			break
	check(not smith._scene_running and not smith.hurtbox.invulnerable and smith.hammer_head.material_override != null, "молот горит духом, бой продолжается")
	var phase_moves := {}
	for i in 1500:
		await frames(1)
		player.health.current = maxf(player.health.current, 50.0)
		if smith.state == Dummy.State.CHASE:
			var boss_gap := 8.0 if not phase_moves.has(Blacksmith.Blow.LEAP) else 5.0
			player.global_position.x = smith.global_position.x + (boss_gap if smith.global_position.x < 4.0 else -boss_gap)
		if smith.state in [Dummy.State.WINDUP, Dummy.State.ATTACK]:
			phase_moves[smith._blow] = true
		if phase_moves.has(Blacksmith.Blow.LEAP) and phase_moves.has(Blacksmith.Blow.HANDS):
			break
	check(phase_moves.has(Blacksmith.Blow.LEAP), "фаза 2: прыжок на героя")
	check(phase_moves.has(Blacksmith.Blow.HANDS), "фаза 2: руки духа из земли")
	boss_probe.queue_free()
	check(not room_node("Objects/BossEcho").enabled, "отзвук кузнеца пока недоступен")
	var hammer_before: float = game_state.mastery_xp(&"hammer")
	check(smith.rank == Dummy.Rank.BOSS, "Кузнец — босс: 5 очков мастерства")
	var sword_before: float = game_state.mastery_xp(&"sword")
	smith.last_weapon = &"sword"
	smith.health.take_damage(INF)
	await seconds(0.8)
	check(game_state.has_flag(&"boss_smith"), "кузнец побеждён")
	check(not room_node("Objects/BossEcho").enabled and not smith.statue and game_state.mastery_xp(&"hammer") == hammer_before,
		"тело ещё не застыло — лута нет")
	# Герой упирается в мёртвое тело и идёт сквозь него: тело стоит.
	var corpse_x := smith.global_position.x
	await put(Vector3(corpse_x - 1.0, smith.global_position.y + 0.1, 0.0), 1.0)
	press("move_right")
	await seconds(0.9)
	release("move_right")
	check(absf(smith.global_position.x - corpse_x) < 0.05, "мёртвое тело не сдвинуть (%.2f)" % (smith.global_position.x - corpse_x))
	check(player.global_position.x > corpse_x, "сквозь тело можно пройти")
	for i in 600:
		await frames(1)
		if game_state.has_flag(&"boss_smith_loot"):
			break
	check(smith.statue and smith.is_inside_tree(), "Кузнец застыл стеклянной статуей на месте")
	check(absf(smith.global_position.x - corpse_x) < 0.05, "статуя стоит, где он умер")
	check(Engine.time_scale == 1.0, "замедление последнего удара кончилось")
	await frames(3)
	check(game_state.mastery_xp(&"hammer") > hammer_before
		and (is_equal_approx(game_state.mastery_xp(&"sword") - sword_before, 5.0) or game_state.mastery_step(&"sword") == 5),
		"после статуи: 5 очков мечу, треть — молоту")
	check(not arena.is_closed(), "туман растворился")
	var echo_find := room_node("Objects/BossEcho") as ItemPickup
	check(echo_find.enabled and echo_find.visible, "отзвук кузнеца появился")
	check(absf(echo_find.global_position.x - (smith.global_position.x + smith.facing * Blacksmith.LOOT_AHEAD)) < 0.01 and echo_find.global_position.z == 0.0,
		"отзвук лежит перед статуей")
	var echoes_smith: int = game_state.echoes
	await put(echo_find.global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.echoes == echoes_smith + 500, "отзвук босса берётся касанием")
	await seconds(1.0)
	await rooms._rest()
	await seconds(0.8)
	var statue := room_node("Objects/Blacksmith") as Blacksmith
	check(statue != null and statue.statue and statue.state == Dummy.State.DEAD and not statue.is_in_group("enemy"),
		"отдых не воскрешает босса: на его месте статуя")

	print("== Перенос к главному осколку")
	var forest_shard := room_node("Objects/MirrorShard") as MirrorShard
	Events.checkpoint_activated.emit(forest_shard)
	for i in 300:
		await frames(1)
		if rooms.level_menu.is_open:
			break
	check(rooms.level_menu.hub_available and rooms.level_menu._hub.visible, "в меню лесного осколка — перенос к часовне")
	rooms.level_menu.go_to_hub()
	for i in 300:
		await frames(1)
		if rooms.current_room_id == &"chapel_yard" and not rooms._busy:
			break
	var hub_shard := room_node("Objects/MirrorShard") as Node3D
	check(rooms.current_room_id == &"chapel_yard" and absf(player.global_position.x - hub_shard.global_position.x) < 3.0,
		"перенёсся к главному осколку у часовни")
	check(game_state.checkpoint_room == &"chapel_yard", "возрождение теперь у часовни")
	Events.checkpoint_activated.emit(hub_shard)
	for i in 300:
		await frames(1)
		if rooms.level_menu.is_open:
			break
	check(not rooms.level_menu.hub_available and not rooms.level_menu._hub.visible, "у главного осколка переноса нет")
	rooms.level_menu.close()
	await seconds(0.3)

	print("== Возвращение к часовне")
	await rooms.travel(&"chapel_yard", ^"Spawns/FromForest")
	await seconds(0.3)
	var herbalist := room_node("Objects/Herbalist") as Npc
	check(herbalist != null and not herbalist.is_queued_for_deletion(), "спасённая Травница у часовни")
	await put(herbalist.global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.item_count(&"flask_potency") == 1, "Травница сделала зелье крепче")
	await rooms.travel(&"chapel", ^"Spawns/FromMirror")
	await seconds(0.3)
	mirror = room_node("Objects/MainMirror") as MainMirror
	check(not mirror.is_locked() and mirror.lit_panes() == 5, "вернулся: Главное Зеркало открылось")
	await put(mirror.global_position + Vector3(0.5, 0.1, 0.0))
	await seconds(0.4)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"room_001", "Главное Зеркало ведёт в замок")
	await put(room_node("Objects/BowFind").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.bow_id == &"bow_guard" and game_state.bow_damage_mult() > 1.0, "в замке — лук стражи: бьёт сильнее")
	rooms.level_menu.switch_bow()
	check(game_state.bow_id == &"bow_hunter", "в меню осколка можно взять другой лук")
	game_state.set_flag(&"has_bow")

	print("== Все лестницы проходимы")
	player.hurtbox.invulnerable = true
	for ladder_room: StringName in [&"village_house", &"chapel", &"cemetery_gate", &"forest_wall", &"fallen_giant", &"root_maze"]:
		var probe_room := (load("res://world/rooms/%s.tscn" % ladder_room) as PackedScene).instantiate()
		var probe_spawn := probe_room.get_node("Spawns").get_child(0).name
		probe_room.free()
		await rooms.travel(ladder_room, NodePath("Spawns/" + probe_spawn))
		await seconds(0.2)
		for pane in nodes_where(rooms.current_room, func(n: Node) -> bool: return n is GlassSurface):
			pane.shatter()
		for foe in get_tree().get_nodes_in_group("enemy"):
			foe.process_mode = Node.PROCESS_MODE_DISABLED
		for node in nodes_where(rooms.current_room, func(n: Node) -> bool: return n is Ladder):
			var each := node as Ladder
			await put(each.global_position + Vector3(0.0, 0.1, 0.0), each.exit_dir)
			press("move_up")
			await seconds(each.height / player.stats.climb_speed + 1.2)
			release("move_up")
			await seconds(0.6)
			check(player.is_on_floor() and player.global_position.y >= each.top_y() - 0.3,
				"%s/%s: долез и встал на пол (y=%.2f, верх %.2f)" % [ladder_room, each.name, player.global_position.y, each.top_y()])
	player.hurtbox.invulnerable = false

	print("== Новая игра при сохранении: герой не пропадает")
	var real_save: String = game_state.save_path
	game_state.save_path = "user://smoke_menu.sav"
	game_state.saves_enabled = true
	rooms.save_now()
	main.queue_free()
	await frames(3)
	var fresh: Node = load("res://main.tscn").instantiate()
	var fresh_rooms := fresh.get_node("RoomManager") as RoomManager
	fresh_rooms.start_room = &"village_hut"
	get_tree().root.add_child(fresh)
	await seconds(2.0)
	var hero := fresh.get_node("Player") as Player
	check(not hero.is_dead() and hero.frozen and fresh_rooms.current_room == null, "меню открыто 2 с — герой жив и ждёт")
	var start_menu: StartMenu
	for child in fresh_rooms.hud.get_children():
		if child is StartMenu:
			start_menu = child
	start_menu.chosen.emit(false)
	await seconds(1.0)
	check(not hero.is_dead() and fresh_rooms.current_room_id == &"village_hut" and absf(hero.global_position.y) < 3.0,
		"«Новая игра»: герой живой, в хижине")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game_state.save_path))
	game_state.saves_enabled = false
	game_state.save_path = real_save
	fresh.queue_free()
	await frames(2)

	# Допуск — кадр твина: сцены Кузнеца поворачивают молот твином, кисть догоняет в следующем кадре.
	check(weapon_gap < 0.02, "оружие врагов всегда в руке: разрыв кисти и рукояти %.3f м %s" % [weapon_gap, weapon_gap_who])

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)
