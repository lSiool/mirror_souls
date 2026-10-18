class_name MirrorShard
extends Interactable
## Чекпоинт — осколок Главного Зеркала (§8.4). Касание задаёт точку возрождения
## и восстанавливает героя.

var lit := false
var _time := 0.0

@onready var crystal: MeshInstance3D = $Crystal
@onready var glow: OmniLight3D = $Glow


func _ready() -> void:
	super()
	prompt = "Коснуться осколка"
	add_to_group("mirror_shard")
	set_lit(false)


func interact(by: Player) -> void:
	by.restore()
	Events.checkpoint_activated.emit(self)
	set_lit(true)
	HitSpark.spawn(get_parent(), crystal.global_position, Color(0.7, 0.9, 1.0), 20)


func set_lit(value: bool) -> void:
	lit = value
	glow.light_energy = 1.6 if lit else 0.35


func get_spawn_position() -> Vector3:
	return global_position + Vector3(0.0, 0.1, 0.0)


func _process(delta: float) -> void:
	_time += delta
	crystal.rotate_y(delta * (1.6 if lit else 0.5))
	crystal.position.y = 1.3 + sin(_time * 2.0) * 0.08
