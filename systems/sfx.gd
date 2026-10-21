extends Node
## Звуковые события (docs/SOUND_PLAN.md): Sfx.play(&"glass_break", где).
## Каждое событие — банк вариантов res://audio/sfx/<группа>/<событие>_NN.wav,
## варианты идут по кругу (round-robin) с лёгким разбросом высоты, чтобы не было «пулемёта».
## Первый слой — запечённый модальный синтез (tools/bake_modal_sounds.gd); библиотечные
## звуки лягут в те же папки и имена.

const ROOT := "res://audio/sfx"
const MAX_VARIANTS := 12
const POOL_SIZE := 16
const PITCH_JITTER := 0.03

## Событие → группа (папка). Событие без файлов молчит — его звук ещё не выбран.
const EVENTS := {
	&"player_step_floor": "player",
	&"player_jump": "player",
	&"player_land": "player",
	&"player_roll": "player",
	&"player_hurt": "player",
	&"player_knee": "player",
	&"player_body_fall": "player",
	&"weapon_drop": "player",
	&"sword_swing": "combat",
	&"sword_hit_body": "combat",
	&"sword_hit_glass": "combat",
	&"sword_block": "combat",
	&"sword_parry": "combat",
	&"critical_pierce": "combat",
	&"critical_release": "combat",
	&"arrow_ricochet_glass": "combat",
	&"arrow_hit_wood": "combat",
	&"bow_draw": "combat",
	&"enemy_hurt": "enemy",
	&"enemy_death": "enemy",
	&"glass_break": "glass",
	&"glass_crack": "glass",
	&"glass_glint": "glass",
	&"glass_glint_trap": "glass",
	&"chest_open": "world",
	&"chest_loot": "world",
	&"death_sting": "ui",
}

## Последнее запрошенное событие и все запрошенные по порядку (для тестов и отладки).
var last_played: StringName = &""
var history: Array[StringName] = []

var _banks := {}
var _next := {}
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


## Проиграть событие в точке мира. Неизвестное событие или пустой банк — тишина.
func play(event: StringName, at: Vector3, volume_db := 0.0) -> void:
	var stream := _take(event)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.global_position = at
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	player.play()


## Звук без места в мире — поверх всего (надпись «ТЫ ПОГИБ»).
func play_ui(event: StringName) -> void:
	var stream := _take(event)
	if stream == null:
		return
	_ui_player.stream = stream
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
