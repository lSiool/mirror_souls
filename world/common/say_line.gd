class_name SayLine
extends Area3D
## Реплика героя, когда он входит в зону: один раз за заход в комнату и только пока
## не стоит until_flag (на выходе из хижины, пока палка не взята, §8.9).

const LAYER_PLAYER := 1 << 1

@export_multiline var text := ""
## Когда этот флаг поставлен, реплика больше не звучит. Пусто — звучит всегда.
@export var until_flag: StringName
@export var size := Vector3(3.0, 3.0, 3.0)

var _said := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _said or not body is Player:
		return
	if until_flag != &"" and GameState.has_flag(until_flag):
		return
	_said = true
	Events.message.emit(text)
