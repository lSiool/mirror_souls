class_name MirrorPortal
extends Interactable
## Зеркало — портал между состояниями пространства (§7.3, §11.3).
## Само ничего не загружает: сообщает RoomManager, куда ведёт и какие правила применить.
## В стекле — «будущий я»: отражение чуть старше героя
## и повторяет его движения с задержкой (§7.4, §9.1).

enum Kind { REALITY, BIOME_GATE, ANOMALY }

## Гул зеркала — петля из самого стекла: громче вблизи, издалека не слышно (docs/SOUND_PLAN.md).
const HUM_PATH := "res://audio/loops/mirror_idle.ogg"
const HUM_VOLUME_DB := -6.0

@export var kind := Kind.REALITY
## Пусто — та же комната.
@export var destination_room: StringName
@export var destination_reality: StringName = &"mirror"
@export var transformations: Array[MirrorTransformation] = []
@export var entry_marker: NodePath = ^"EntryMarker"
@export var reflection_delay := 0.3
## Отражение немного взрослее героя: обычное зеркало — на 1–2 года.
@export var reflection_age_scale := 1.05
@export var half_width := 0.8
@export var glass_height := 2.6

var hum: AudioStreamPlayer3D
var _time := 0.0
var _history: Array[Dictionary] = []
var _player: Player

@onready var reflection: Node3D = $Reflection


func _ready() -> void:
	super()
	prompt = "Шагнуть в зеркало"
	reflection.visible = false
	reflection.scale = Vector3(reflection_age_scale, reflection_age_scale, 0.35)
	_start_hum()


func _start_hum() -> void:
	if not ResourceLoader.exists(HUM_PATH):
		return
	var stream := load(HUM_PATH) as AudioStreamOggVorbis
	stream.loop = true
	hum = AudioStreamPlayer3D.new()
	hum.stream = stream
	hum.volume_db = HUM_VOLUME_DB
	hum.unit_size = 2.5
	hum.max_distance = 14.0
	hum.position = Vector3(0.0, glass_height * 0.5, 0.0)
	add_child(hum)
	# Разные зеркала гудят не в такт.
	hum.play(randf() * stream.get_length())


func interact(_by: Player) -> void:
	Events.mirror_used.emit(self)


func get_entry_position() -> Vector3:
	return get_node(entry_marker).global_position


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	_history.append({"t": _time, "pos": _player.global_position, "facing": _player.facing})
	while _history.size() > 2 and _history[1]["t"] <= _time - reflection_delay:
		_history.pop_front()
	var sample: Dictionary = _history[0]
	var pos: Vector3 = sample["pos"]
	var local := pos - global_position
	var in_frame := local.y > -0.5 and local.y < glass_height - 1.0
	reflection.visible = in_frame and absf(local.x) < half_width + 0.3
	if reflection.visible:
		reflection.global_position = Vector3(pos.x, pos.y, reflection.global_position.z)
		reflection.rotation.y = 0.0 if sample["facing"] > 0.0 else PI
