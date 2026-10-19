class_name ArrowTarget
extends Area3D
## Мишень для стрел — основа для механизмов лука (§6.2): подвесы, противовес,
## мишень-механизм с дверью на время, жаровня. Через hits_required попаданий — triggered.

signal struck(hits: int)
signal triggered

const LAYER_ARROW_TARGET := 1 << 5

@export var hits_required := 1

var hits := 0


func _ready() -> void:
	collision_layer = LAYER_ARROW_TARGET
	collision_mask = 0
	monitoring = false
	monitorable = true


func arrow_hit(_arrow: Node) -> void:
	if hits >= hits_required:
		return
	hits += 1
	struck.emit(hits)
	if hits >= hits_required:
		triggered.emit()
