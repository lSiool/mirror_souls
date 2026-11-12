extends Node3D
## Дальние осколки нестабильного отражения (§8.11): дети этого узла медленно плывут навстречу
## герою и вращаются; уплывшие далеко за спину возвращаются вперёд — пространство бесконечно.

@export var speed := Vector3(-2.2, 0.0, 0.0)
## Ширина полосы вокруг героя, в которой живут осколки.
@export var span := 150.0

var _player: Node3D


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	var i := 0
	for child in get_children():
		var piece := child as Node3D
		if piece == null:
			continue
		i += 1
		piece.position += speed * delta * (0.5 + 0.25 * (i % 4))
		piece.rotation += Vector3(0.11, 0.07, 0.05) * delta * (1.0 + i % 3)
		if piece.global_position.x < _player.global_position.x - span * 0.5:
			piece.position.x += span
