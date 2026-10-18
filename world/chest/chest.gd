class_name Chest
extends Interactable
## Сундук с «бликами» (валюта). Открытый сундук остаётся открытым после смерти:
## мир постоянен (§8.5).

@export var reward := 50
## Уникальный флаг мира. Пусто — сундук закрывается снова при перезагрузке комнаты.
@export var flag_id: StringName

var opened := false

@onready var lid: Node3D = $Lid


func _ready() -> void:
	super()
	prompt = "Открыть сундук"
	if flag_id != &"" and GameState.has_flag(flag_id):
		_open(false)


func interact(_by: Player) -> void:
	if opened:
		return
	_open(true)
	GameState.add_currency(reward)
	if flag_id != &"":
		GameState.set_flag(flag_id)
	HitSpark.spawn(get_parent(), global_position + Vector3(0, 0.8, 0.3), Color(1.0, 0.85, 0.35), 24)


func _open(animate: bool) -> void:
	opened = true
	enabled = false
	if animate:
		create_tween().tween_property(lid, "rotation:x", -1.9, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation.x = -1.9
