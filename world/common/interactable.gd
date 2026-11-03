class_name Interactable
extends Area3D
## Объект, с которым игрок взаимодействует кнопкой `interact`: сундук, осколок, зеркало.

const LAYER_INTERACTABLE := 1 << 3
const LAYER_PLAYER := 1 << 1

@export var prompt := "Взаимодействовать"

var enabled := true


func _ready() -> void:
	collision_layer = LAYER_INTERACTABLE
	collision_mask = LAYER_PLAYER
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact(_player: Player) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.add_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		body.remove_interactable(self)
