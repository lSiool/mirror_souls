extends Node
## Конец первой сцены (§9.2): бой мальчишки с оборотнем нельзя выиграть, но можно пережить.
## Герой обессилел, или зверь ранен настолько, что остаётся отметина, или бой просто затянулся:
## из леса доносится зов, зверь уходит, герой теряет сознание и приходит в себя, когда огонь стих.

const FIRE_OUT: StringName = &"fire_out"
## Сумел ранить зверя палкой. Зверь запомнит: пригодится при новой встрече.
const SCARRED: StringName = &"wolf_scarred"
const SCAR_AT := 0.5
const FIGHT_LIMIT := 90.0
const HOWL_DB := -4.0

var _done := false
var _time := 0.0
var _wolf: Werewolf
var _player: Player


func _ready() -> void:
	if GameState.has_flag(FIRE_OUT):
		set_process(false)
		return
	_wolf = owner.get_node("Objects/Werewolf") as Werewolf
	_player = get_tree().get_first_node_in_group("player") as Player
	_wolf.health.changed.connect(_on_wolf_health)
	_player.health_changed.connect(_on_hero_health)


func _process(delta: float) -> void:
	if not _done and _wolf.engaged:
		_time += delta
		if _time >= FIGHT_LIMIT:
			_finish(false)


func _on_hero_health(current: float, _maximum: float) -> void:
	if current <= 1.0 and not _done:
		_finish(false)


func _on_wolf_health(current: float, maximum: float) -> void:
	if current <= maximum * SCAR_AT and not _done:
		_finish(true)


func _finish(scarred: bool) -> void:
	_done = true
	var rooms := owner.get_parent() as RoomManager
	if scarred:
		GameState.set_flag(SCARRED)
		Events.message.emit("На морде зверя остаётся отметина от палки.")
	_player.knock_down()
	_wolf.heed_call()
	await get_tree().create_timer(0.6).timeout
	Sfx.play_ui(&"distant_howl", HOWL_DB)
	Events.message.emit("Из леса доносится зов. Зверь поднимает морду.")
	await get_tree().create_timer(1.6).timeout
	_wolf.flee()
	await get_tree().create_timer(1.0).timeout
	rooms.wake_up(FIRE_OUT, ^"Spawns/AfterWolf", "Огонь стих. Деревня молчит.")
