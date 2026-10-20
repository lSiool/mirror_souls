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

## Событие → группа (папка).
const EVENTS := {
	&"sword_hit_glass": "combat",
	&"sword_block": "combat",
	&"sword_parry": "combat",
	&"arrow_ricochet_glass": "combat",
	&"arrow_hit_wood": "combat",
	&"glass_break": "glass",
	&"glass_glint": "glass",
	&"glass_glint_trap": "glass",
}

## Последнее проигранное событие (для тестов и отладки).
var last_played: StringName = &""

var _banks := {}
var _next := {}
var _players: Array[AudioStreamPlayer3D] = []
var _next_player := 0


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
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 8.0
		player.max_distance = 60.0
		add_child(player)
		_players.append(player)


## Проиграть событие в точке мира. Неизвестное событие или пустой банк — тишина.
func play(event: StringName, at: Vector3, volume_db := 0.0) -> void:
	var bank: Array[AudioStream] = _banks.get(event, [] as Array[AudioStream])
	if bank.is_empty():
		return
	var index: int = _next[event]
	_next[event] = (index + 1) % bank.size()
	var player := _free_player()
	player.stream = bank[index]
	player.global_position = at
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	player.play()
	last_played = event


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
