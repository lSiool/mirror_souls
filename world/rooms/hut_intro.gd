extends Node
## Начало игры (§9.2). Один раз: заставка-сон (заглушка: строки на чёрном вместо ролика), потом
## герой лежит под крики и треск огня, громко бьётся сердце, он встаёт: это уже не сон.

const FLAG: StringName = &"intro_done"
## Сон видели: его не показывать второй раз (и в тестах).
const DREAM_FLAG: StringName = &"dream_seen"
const DREAM := [
	"Мальчик с палкой. Он бежит, представляя себя великим героем.",
	"Пираты.",
	"Зомби, нежить.",
	"Летуны.",
	"Мумии.",
	"Чародей.",
	"Владыка.",
	"И он взрослеет…",
]
const HEARTBEATS := 3
const HEARTBEAT_GAP := 0.72
const CALL_DELAY := 1.2
const SCREAM_DB := -8.0


func _ready() -> void:
	if not GameState.has_flag(FLAG):
		run.call_deferred()


func run() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var rooms := owner.get_parent() as RoomManager
	GameState.set_flag(FLAG)
	player.frozen = true
	player.lying = true
	if not GameState.has_flag(DREAM_FLAG):
		GameState.set_flag(DREAM_FLAG)
		await rooms.hud.play_cards(PackedStringArray(DREAM))
	Events.message.emit("Крики. Пожар. Хаос.")
	for i in HEARTBEATS:
		Sfx.play_ui(&"heartbeat")
		await get_tree().create_timer(HEARTBEAT_GAP).timeout
	player.lying = false
	player.frozen = false
	Events.message.emit("И теперь… это не сон.")
	await get_tree().create_timer(CALL_DELAY).timeout
	Sfx.play_ui(&"villager_call", SCREAM_DB)
	Events.message.emit("Снаружи кто-то зовёт на помощь.")
