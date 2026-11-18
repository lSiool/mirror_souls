extends SceneTree
func _initialize() -> void:
	var s := (load("res://assets/characters/werewolf_young/werewolf_young.glb") as PackedScene).instantiate()
	_dump(s, "")
	s.free()
	quit()
func _dump(n: Node, ind: String) -> void:
	var extra := ""
	if n is Skeleton3D:
		extra = " bones=%d first=%s" % [(n as Skeleton3D).get_bone_count(), (n as Skeleton3D).get_bone_name(0)]
	print(ind, n.name, " <", n.get_class(), ">", extra, " path=", n.owner.get_path_to(n) if n.owner else ".")
	for c in n.get_children():
		_dump(c, ind + "  ")
