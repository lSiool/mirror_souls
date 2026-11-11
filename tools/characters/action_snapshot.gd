extends Node
## Снимки героя по сценарию из командной строки (§3.3) — чтобы проверить позу без нового скрипта.
## Нужен рендер — запускать без --headless (в облаке — через xvfb-run):
##   godot --path . res://tools/characters/action_snapshot.tscn -- room=room_001 at=-9,0.1 press:block wait:0.1 shot:parry release:block
## Шаги: press:<действие>, release:<действие>, wait:<секунды>, shot:<имя>, flag:<флаг мира>,
## item:<предмет>, mastery:<тип оружия> (первая ступень), equip:<оружие>, foes:on (враги по умолчанию стоят). Картинки — в user://action_snapshots/.

const OUT := "user://action_snapshots"

var _player: Player


func _ready() -> void:
	var room := &"room_001"
	var at := Vector2(-9.0, 0.1)
	var steps: Array[String] = []
	var foes := false
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("room="):
			room = StringName(arg.trim_prefix("room="))
		elif arg.begins_with("at="):
			var xy := arg.trim_prefix("at=").split(",")
			at = Vector2(float(xy[0]), float(xy[1]))
		elif arg.begins_with("flag:"):
			GameState.set_flag(StringName(arg.trim_prefix("flag:")))
		elif arg.begins_with("item:"):
			GameState.add_item(StringName(arg.trim_prefix("item:")))
		elif arg.begins_with("mastery:"):
			GameState.add_mastery(StringName(arg.trim_prefix("mastery:")), 20.0)
		elif arg == "foes:on":
			foes = true
		else:
			steps.append(arg)
	var main: Node = load("res://main.tscn").instantiate()
	main.get_node("RoomManager").start_room = room
	get_tree().root.add_child.call_deferred(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.5).timeout
	var rooms := main.get_node("RoomManager") as RoomManager
	_player = main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	rooms.hud.popup.blocks_interact = false
	# Программный рендер не знает прозрачности узла: капсулу и клинок-призрак убираем со слоёв.
	for node in _player.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).transparency >= 0.99:
			(node as GeometryInstance3D).layers = 0
	if not foes:
		for foe in get_tree().get_nodes_in_group("enemy"):
			foe.process_mode = Node.PROCESS_MODE_DISABLED
	_player.teleport(Vector3(at.x, at.y, 0.0))
	_player.facing = 1.0
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(0.4).timeout
	for step in steps:
		var value := step.get_slice(":", 1)
		match step.get_slice(":", 0):
			"press": Input.action_press(value)
			"release": Input.action_release(value)
			"wait": await get_tree().create_timer(float(value)).timeout
			"equip": _player.equip(StringName(value))
			"shot": await _shot(value)
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cam := get_viewport().get_camera_3d()
	# Окно растянуто от базового разрешения проекта: точку героя переводим в пиксели снимка.
	var at := cam.unproject_position(_player.global_position + Vector3(0.0, 1.0, 0.0)) \
		* (Vector2(img.get_size()) / get_viewport().get_visible_rect().size)
	var rect := Rect2i(int(at.x) - 150, int(at.y) - 170, 300, 300).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png("%s/%s.png" % [OUT, shot_name])
