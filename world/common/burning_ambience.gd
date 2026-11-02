class_name BurningAmbience
extends Node
## Звук горящей деревни (§9.2): треск огня и голос, который зовёт на помощь и ведёт героя вперёд.

const CRACKLE_PATH := "res://audio/loops/fire_crackle.ogg"
const CRACKLE_DB := -16.0
const VOICE_DB := -8.0

## Что слышит герой, по очереди. Пусто — только огонь.
@export var calls := PackedStringArray()
@export var every := 12.0

var _wait := 3.0
var _next := 0


func _ready() -> void:
	if ResourceLoader.exists(CRACKLE_PATH):
		var stream := load(CRACKLE_PATH) as AudioStreamOggVorbis
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = CRACKLE_DB
		add_child(player)
		player.play()


func _process(delta: float) -> void:
	if calls.is_empty():
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = every
		Sfx.play_ui(&"villager_call", VOICE_DB)
		Events.message.emit(calls[_next])
		_next = (_next + 1) % calls.size()
