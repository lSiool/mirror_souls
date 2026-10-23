extends Node
## Звуковые события (docs/SOUND_PLAN.md): Sfx.play(&"glass_break", где).
## Каждое событие — банк вариантов res://audio/sfx/<группа>/<событие>_NN.wav,
## варианты идут по кругу (round-robin) с лёгким разбросом высоты, чтобы не было «пулемёта».
## Банки собираются из записей Kenney (tools/sound/make_candidates.py --bank),
## блики стекла — модальным синтезом (tools/bake_modal_sounds.gd).

const ROOT := "res://audio/sfx"
const MAX_VARIANTS := 12
const POOL_SIZE := 16
const PITCH_JITTER := 0.03

## Событие → группа (папка). Событие без файлов молчит — его звук ещё не выбран.
const EVENTS := {
	&"player_step_floor": "player",
	&"player_jump": "player",
	&"player_jump_voice": "player",
	&"player_land": "player",
	&"player_roll": "player",
	&"player_hurt": "player",
	&"player_fall_hurt": "player",
	&"player_knee": "player",
	&"player_body_fall": "player",
	&"weapon_drop": "player",
	&"sword_swing": "combat",
	&"sword_swing_thrust": "combat",
	&"sword_hit": "combat",
	&"sword_hit_finisher": "combat",
	&"sword_hit_glass": "combat",
	&"sword_block": "combat",
	&"sword_parry": "combat",
	&"critical_pierce": "combat",
	&"critical_release": "combat",
	&"arrow_ricochet_glass": "combat",
	&"arrow_hit_wood": "combat",
	&"bow_draw": "combat",
	&"bow_release": "combat",
	&"enemy_hurt": "enemy",
	&"enemy_hurt_voice": "enemy",
	&"enemy_death": "enemy",
	&"enemy_death_voice": "enemy",
	&"glass_break": "glass",
	&"glass_crack": "glass",
	&"glass_glint": "glass",
	&"glass_glint_trap": "glass",
	&"chest_open": "world",
	&"chest_loot": "world",
	&"death_sting": "ui",
}

## Слои, которые звучат не каждый раз: [вероятность, пауза после звучания (с), сколько раз подряд
## можно промолчать]. Голос на каждом ударе быстро надоедает. Голос прыжка выбирает сам герой
## (только прыжок с усилием, Player.jump_is_effort) — здесь лишь пауза, чтобы не частил.
const SOMETIMES := {
	&"player_jump_voice": [1.0, 1.2, 0],
	&"enemy_hurt_voice": [0.5, 0.8, 2],
}

## Последнее запрошенное событие и все запрошенные по порядку (для тестов и отладки).
## Пропущенный слой SOMETIMES сюда не попадает: в истории только то, что прозвучало.
var last_played: StringName = &""
var history: Array[StringName] = []

var _banks := {}
var _next := {}
var _last_time := {}
var _skipped := {}
var _players: Array[AudioStreamPlayer3D] = []
var _next_player := 0
var _ui_player: AudioStreamPlayer


func _ready() -> void:
	for event: StringName in EVENTS:
		var bank: Array[AudioStream] = []
		for i in MAX_VARIANTS:
			var path := "%s/%s/%s_%02d.wav" % [ROOT, EVENTS[event], event, i + 1]
			if not ResourceLoader.exists(path):
				break
			bank.append(load(path))
		_banks[event] = bank
		_next[event] = 0
	_ui_player = AudioStreamPlayer.new()
	add_child(_ui_player)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 8.0
		player.max_distance = 60.0
		add_child(player)
		_players.append(player)


## Проиграть событие в точке мира. Неизвестное событие, пустой банк или пропущенный слой
## SOMETIMES — тишина и null. Возвращает плеер, чтобы звук можно было оборвать (Sfx.stop).
func play(event: StringName, at: Vector3, volume_db := 0.0) -> AudioStreamPlayer3D:
	if event == &"" or (event in SOMETIMES and not _sometimes(event)):
		return null
	var stream := _take(event)
	if stream == null:
		return null
	var player := _free_player()
	player.stream = stream
	player.global_position = at
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	player.play()
	return player


## Оборвать звук с коротким затуханием (тетиву отпустили до полного натяжения).
func stop(player: AudioStreamPlayer3D, fade := 0.06) -> void:
	if player == null or not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", player.volume_db - 30.0, fade)
	tween.tween_callback(player.stop)


## Звучит ли слой сейчас: не чаще паузы, с вероятностью, но не молчит дольше заданного.
func _sometimes(event: StringName) -> bool:
	var rule: Array = SOMETIMES[event]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_time.get(event, -INF)) < rule[1]:
		return false
	var skipped: int = _skipped.get(event, 0)
	if skipped < rule[2] and randf() >= rule[0]:
		_skipped[event] = skipped + 1
		return false
	_skipped[event] = 0
	_last_time[event] = now
	return true


## Звук без места в мире — поверх всего (надпись «ТЫ ПОГИБ»).
func play_ui(event: StringName, volume_db := 0.0) -> void:
	var stream := _take(event)
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.volume_db = volume_db
	_ui_player.play()


## Следующий вариант события по кругу или null, если файлов нет.
func _take(event: StringName) -> AudioStream:
	last_played = event
	history.append(event)
	if history.size() > 64:
		history.remove_at(0)
	var bank: Array[AudioStream] = _banks.get(event, [] as Array[AudioStream])
	if bank.is_empty():
		return null
	var index: int = _next[event]
	_next[event] = (index + 1) % bank.size()
	return bank[index]


func variants(event: StringName) -> int:
	var bank: Array[AudioStream] = _banks.get(event, [] as Array[AudioStream])
	return bank.size()


func _free_player() -> AudioStreamPlayer3D:
	for i in POOL_SIZE:
		var player := _players[(_next_player + i) % POOL_SIZE]
		if not player.playing:
			_next_player = (_next_player + i + 1) % POOL_SIZE
			return player
	# Все заняты — перебиваем самый старый.
	var oldest := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return oldest
