extends Node
## Хитстоп (§6.1): мир на миг замирает при попадании. Тяжёлый удар держит дольше.
## Отсчёт идёт в реальном времени, поэтому замедление само себя не растягивает.

const SLOW_SCALE := 0.05

var _remaining := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func stop(duration: float) -> void:
	_remaining = maxf(_remaining, duration)
	Engine.time_scale = SLOW_SCALE


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining -= delta / Engine.time_scale
	if _remaining <= 0.0:
		Engine.time_scale = 1.0
