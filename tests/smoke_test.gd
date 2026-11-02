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


## Прозвучало ли событие с последней очистки истории звуков.
func heard(event: StringName) -> bool:
	return sfx.history.has(event)


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
	player.health.take_damage(70.0)
	await tap("heal")
	check(player.state == Player.State.DRINK and player.flasks == 1, "пьёт зелье, глотков осталось 1")
	await seconds(1.0)
	check(absf(player.health.current - 90.0) < 0.5, "глоток лечит 60 %% (здоровье %.0f)" % player.health.current)
	await tap("heal")
	await seconds(1.0)
	check(player.health.current == player.stats.max_health and player.flasks == 0, "второй глоток — до полного, глотков 0")
	await tap("heal")
	check(player.state != Player.State.DRINK, "зелье кончилось — пить нечего")

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
	game_state.add_echoes(cost - 1 - game_state.echoes)
	menu._refresh()
	await menu.choose(PlayerStats.Param.HEALTH)
	check(stats.level == 0 and game_state.echoes == cost - 1, "не хватает отзвуков — уровня нет")
	game_state.add_echoes(1)
	await menu.choose(PlayerStats.Param.HEALTH)
	check(stats.level == 1 and game_state.echoes == 0, "уровень куплен за %d отзвуков" % cost)
	check(is_equal_approx(stats.current_age, age_before + 0.25), "герой повзрослел на четверть года (%.2f)" % stats.current_age)
	check(stats.max_health > stats.base_health and is_equal_approx(player.health.max_health, stats.max_health),
		"здоровье выросло (%.1f)" % stats.max_health)
	check(stats.move_speed < speed_before, "годы забрали скорость (%.3f → %.3f)" % [speed_before, stats.move_speed])
	game_state.add_item(&"clear_glass")
	menu.use_clear_glass()
	check(stats.unspent == 1 and is_equal_approx(stats.max_health, stats.base_health)
		and is_equal_approx(stats.current_age, age_before + 0.25) and game_state.item_count(&"clear_glass") == 0,
		"чистое стекло: очко свободно, возраст тот же")
	await menu.choose(PlayerStats.Param.STRENGTH)
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
	stats.points[PlayerStats.Param.HEALTH] = 2000
	check(stats.max_health <= stats.base_health + stats.health_bonus_cap, "здоровье не выше потолка (%.0f)" % stats.max_health)
	stats.reset_progress()
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
		game_state.add_mastery(&"sword", 1.0)
		kills += 1
	check(kills == 50 and player.weapon.combo_at(1).size() == 4, "первая ступень за 50 врагов: четвёртый удар")
	game_state.mastery.clear()
	kills = 0
	while game_state.mastery_step(&"sword") < 1 and kills < 200:
		game_state.add_mastery(&"sword", 1000.0)
		kills += 1
	check(kills == 15, "даже сильные враги: не меньше 15 убийств на ступень (%d)" % kills)
	game_state.mastery.clear()
	stats.level = 60
	check(is_equal_approx(stats.mastery_rate(), 2.0), "взрослому опыт идёт вдвое быстрее")
	stats.level = 0
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
	await seconds(0.3)
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
	check(game_state.echoes == 0 and game_state.hero_echo.get("amount", 0) == 50,
		"смерть: половина пропала, половина — в отзвуке героя (%d)" % game_state.hero_echo.get("amount", 0))
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
	check(game_state.hero_echo.get("amount", 0) == 20 and hero_echoes.size() == 1,
		"погиб снова, не забрав: прежний отзвук пропал, в новом половина (%d)" % game_state.hero_echo.get("amount", 0))
	if hero_echoes.size() == 1:
		await put(hero_echoes[0].global_position + Vector3(0.0, 0.1, 0.0))
		await seconds(0.2)
		await tap("interact")
		await seconds(0.8)
	check(game_state.echoes == 20 and game_state.hero_echo.is_empty(), "коснулся отзвука — отзвуки вернулись (%d)" % game_state.echoes)

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
	await put(room_node("Objects/Stick").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.3)
	await tap("interact")
	await frames(3)
	check(player.weapon != null and player.weapon.id == &"stick" and game_state.has_flag(&"got_stick"), "подобрал палку")
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
		if wolf_moves.size() == 3 and wolf_hit:
			break
	check(wolf_moves.has(Werewolf.Move.CLAW), "оборотень бьёт когтями")
	check(wolf_moves.has(Werewolf.Move.RUSH), "оборотень бросается рывком")
	check(wolf_moves.has(Werewolf.Move.LEAP), "оборотень прыгает")
	check(wolf_hit, "удары оборотня достают героя")
	# Поражение: героя не убить, зов уводит зверя, герой приходит в себя, когда огонь стих.
	player.restore()
	for i in 3600:
		await frames(1)
		if not wolf.is_inside_tree() or wolf._called:
			break
		player.global_position.x = wolf.global_position.x + 1.5 * wolf.facing
	check(not player.is_dead() and player.lying and player.frozen, "мальчишка повержен, но жив")
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
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check((room_node("Objects/Smith") as Npc)._next == 1, "дальше кузнец рассказывает")
	check(room_node("Objects/Herbalist") != null and room_node("Objects/Glassblower") != null, "травница и стекольщик на месте")
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
	check(mirror.lit_panes() == 2 and mirror.get_node_or_null("Pane2") != null, "открыты два куска из трёх")
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
	check(rooms.current_room_id == &"forest_trail", "из деревни в лес")

	print("== Тропа в лесу")
	check(room_node("Objects/RatA") != null and room_node("Objects/Bat") != null, "в лесу есть враги")
	await put(Vector3(-5.0, 0.3, 0.0), 1.0)
	press("move_right")
	await seconds(1.1)
	release("move_right")
	check(player.global_position.y > 1.0, "тропа поднимается на холм (y=%.2f)" % player.global_position.y)
	await put(room_node("Objects/DoorToForge").global_position + Vector3(-0.5, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"forge_yard", "тропа привела к старой кузне")

	print("== Двор кузницы")
	await put(room_node("Objects/MirrorShard").global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await seconds(1.2)
	rooms.level_menu.close()
	check(game_state.has_flag(&"shard_forge_yard"), "осколок двора активирован")
	var smith := room_node("Objects/Blacksmith") as Blacksmith
	check(smith != null and smith.health.max_health == 300.0, "кузнец на месте")
	player.restore()
	await put(Vector3(smith.global_position.x - 2.2, 0.1, 0), 1.0)
	smith.facing = -1.0
	var hp_smith := player.health.current
	var saw_slam := false
	var hammer_head := smith.hammer.get_node("Head") as Node3D
	var hammer_top := 0.0
	var smith_hit := false
	var hp_frame := player.health.current
	for i in 900:
		await frames(1)
		smith_hit = smith_hit or player.health.current < hp_frame
		player.health.current = maxf(player.health.current, 40.0)
		hp_frame = player.health.current
		saw_slam = saw_slam or (smith.state == Dummy.State.WINDUP and smith._blow == Blacksmith.Blow.SLAM)
		if smith.state == Dummy.State.WINDUP and smith._blow == Blacksmith.Blow.SLAM:
			hammer_top = maxf(hammer_top, hammer_head.global_position.y - smith.global_position.y)
		if saw_slam and smith.state == Dummy.State.RECOVER:
			break
	check(saw_slam, "кузнец заносит молот сверху (удар №3)")
	check(smith_hit, "удар Кузнеца достаёт героя, хотя модель стоит глубже")
	check(hammer_top > 3.2, "молот поднят над головой (%.1f м)" % hammer_top)
	await seconds(0.25)
	check(hammer_head.global_position.y - smith.global_position.y < 0.8, "молот упал до земли (%.1f м)" % (hammer_head.global_position.y - smith.global_position.y))
	check(smith.recover_time >= smith.slam_stuck * 0.7, "после удара сверху молот застревает в камне (%.1f с)" % smith.recover_time)
	check(smith.hurt_voice == &"" and smith.death_voice == &"", "Кузнец безмолвен")
	check(not smith.backstab_allowed, "у Кузнеца нет добивания в спину: перекат за спину его не даёт")
	check(rooms.hud.boss_bar != null, "у босса полоса здоровья")
	check(hp_smith > 0.0, "герой жив")
	await seconds(0.2)
	# Герой всегда перед Кузнецом: модель и молот не перекрывают его, куда бы тот ни смотрел.
	for side in 2:
		check(smith.body_mesh.global_position.z + 0.55 < -0.38 and hammer_head.global_position.z + 0.35 < 0.0, "модель и молот за героем (facing %.0f)" % smith.facing)
		smith.facing = -smith.facing
		await frames(2)
	# Перекат сквозь босса: без переката он твёрдый, из переката выходим за спиной.
	var smith_home := smith.global_position
	var smith_reach: float = smith.body_half_width() + 0.3
	smith.set_physics_process(false)
	await put(Vector3(smith_home.x - 1.5, 0.1, 0), 1.0)
	press("move_right")
	await seconds(0.6)
	release_all()
	check(player.global_position.x < smith_home.x - smith_reach, "шагом сквозь Кузнеца не пройти")
	player.stamina = player.stats.max_stamina
	await tap("roll")
	await seconds(0.6)
	check(player.global_position.x > smith_home.x + smith_reach, "перекат выводит за спину Кузнеца")
	check(player._rolled_through.is_empty(), "после переката босс снова твёрдый")
	# Издали перекат кончился бы внутри босса: докатывается до выхода.
	await put(Vector3(smith_home.x - 3.4, 0.1, 0), 1.0)
	player.stamina = player.stats.max_stamina
	await tap("roll")
	await seconds(0.9)
	check(player.global_position.x > smith_home.x + smith_reach, "перекат не заканчивается внутри босса")
	check(player.state == Player.State.MOVE, "перекат закончился (%s)" % player.state)
	# Босс у стены: упёрлись — выходим обратно, а не застреваем.
	var smith_wall := Vector3(-22.3, smith_home.y, 0.0)
	smith.global_position = smith_wall
	await put(Vector3(smith_wall.x + 1.3, 0.1, 0), -1.0)
	player.stamina = player.stats.max_stamina
	await tap("roll")
	await seconds(1.0)
	check(absf(player.global_position.x - smith_wall.x) >= smith_reach, "у стены из босса выходим обратно")
	check(player.state == Player.State.MOVE and player._rolled_through.is_empty(), "у стены перекат закончился")
	smith.global_position = smith_home
	smith.set_physics_process(true)
	await put(Vector3(smith_home.x - 2.2, 0.1, 0), 1.0)
	check(not room_node("Objects/BossEcho").enabled, "отзвук кузнеца пока недоступен")
	smith.health.take_damage(smith.health.max_health * 0.6)
	check(smith._enraged(), "на половине здоровья кузнец злее")
	var hammer_before: float = game_state.mastery_xp(&"hammer")
	smith.last_weapon = &"sword"
	smith.health.take_damage(INF)
	await frames(2)
	check(game_state.mastery_xp(&"hammer") > hammer_before, "победа над кузнецом учит молоту")
	await seconds(0.5)
	check(game_state.has_flag(&"boss_smith"), "кузнец побеждён")
	var echo_find := room_node("Objects/BossEcho") as ItemPickup
	check(echo_find.enabled and echo_find.visible, "отзвук кузнеца появился")
	var echoes_smith: int = game_state.echoes
	await put(echo_find.global_position + Vector3(0.0, 0.1, 0.0))
	await seconds(0.2)
	await tap("interact")
	await frames(3)
	check(game_state.echoes == echoes_smith + 500, "отзвук босса берётся касанием")
	await seconds(1.0)
	await rooms._rest()
	await seconds(0.8)
	check(room_node("Objects/Blacksmith") == null or room_node("Objects/Blacksmith").is_queued_for_deletion(), "отдых не воскрешает босса")
	await rooms.travel(&"chapel", ^"Spawns/FromMirror")
	await seconds(0.3)
	mirror = room_node("Objects/MainMirror") as MainMirror
	check(not mirror.is_locked() and mirror.lit_panes() == 3, "вернулся: Главное Зеркало открылось")
	await put(mirror.global_position + Vector3(0.5, 0.1, 0.0))
	await seconds(0.4)
	await tap("interact")
	await seconds(1.0)
	check(rooms.current_room_id == &"room_001", "Главное Зеркало ведёт в замок")
	game_state.set_flag(&"has_bow")

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)
