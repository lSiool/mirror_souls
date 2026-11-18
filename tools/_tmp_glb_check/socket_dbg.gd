extends SceneTree
## Глазницы шлема (точки модели Blender: x, y — вперёд минус, z) → координаты в креплении кости головы.
func _init() -> void:
	await process_frame
	var enemy := (load("res://actors/enemies/blacksmith.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(enemy)
	await process_frame
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var model = enemy.get(&"model")
	var sk: Skeleton3D = model.hero.skeleton
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	var mesh := sk.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	if mesh == null:
		mesh = model.hero.find_children("*", "MeshInstance3D", true, false)[0]
	var head: Node3D = model.head_attachment()
	await process_frame
	var hb := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("Head"))
	print("skeleton scale ", sk.global_transform.basis.get_scale(), " mesh scale ", mesh.global_transform.basis.get_scale(), " head att scale ", head.global_transform.basis.get_scale())
	for p in [Vector3(-0.038, 1.713, 0.105), Vector3(0.038, 1.713, 0.105), Vector3(0.0, 1.638, 0.0)]:
		var g: Vector3 = mesh.global_transform * p
		print("blender(x,z,-y)=", p, " -> head local ", (head.global_transform.affine_inverse() * g).snapped(Vector3.ONE * 0.001), "  bone-rest local ", (hb.affine_inverse() * g).snapped(Vector3.ONE * 0.001))
	quit()
