extends SceneTree
func _init() -> void:
	var s := (load("res://assets/characters/anims/mixamo/Zombie Scream.fbx") as PackedScene).instantiate()
	var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a := ap.get_animation(ap.get_animation_list()[-1])
	print("LEN ", a.length, " path0 ", a.track_get_path(0))
	s.free(); quit()
