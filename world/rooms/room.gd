class_name Room
extends Node3D
## Комната — только раскладка и данные. Как работают зеркала, знает RoomManager (§11.1).
##
## Соглашения:
## - прямые дети комнаты — контейнеры в начале координат (Geometry, Spawns, Objects…);
##   трансформации отражения двигают объекты внутри контейнеров;
## - узел в группе "<реальность>_only" (например "normal_only", "mirror_only")
##   существует только в этой реальности.

@export var room_id: StringName = &"room_001"
## Ось, относительно которой FlipX зеркалит раскладку.
@export var center_x := 0.0
@export var width := 40.0


## Удаляет узлы, принадлежащие другим реальностям. Вызывается до добавления в дерево.
func apply_reality(reality: StringName) -> void:
	var keep := String(reality) + "_only"
	var doomed: Array[Node] = []
	for node in _descendants(self):
		for group in node.get_groups():
			var g := String(group)
			if g.ends_with("_only") and g != keep:
				doomed.append(node)
				break
	for node in doomed:
		if is_instance_valid(node):
			node.free()


## Объекты раскладки: дети контейнеров.
func layout_objects() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for container in get_children():
		for node in container.get_children():
			if node is Node3D:
				result.append(node)
	return result


func _descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
