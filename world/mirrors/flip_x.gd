class_name FlipX
extends MirrorTransformation
## Зеркалит раскладку комнаты по X относительно её центра (§12.3).
## Двигаем позиции и разворачиваем повороты — без scale.x = -1: Godot не поддерживает
## отрицательный масштаб коллизий. Физика честная, потому что зеркалятся данные.
## Объект может реализовать on_mirrored(), чтобы развернуть что-то своё (например, взгляд врага).


func apply(room: Room) -> void:
	for node in room.layout_objects():
		var p := node.position
		node.position = Vector3(2.0 * room.center_x - p.x, p.y, p.z)
		var r := node.rotation
		node.rotation = Vector3(r.x, -r.y, -r.z)
		if node.has_method("on_mirrored"):
			node.on_mirrored()
