extends Node
## Снимки сюжетного забега «Нестабильное отражение» (§8.11): старт, глыбы на подлёте, пластины,
## обломки, стена схлопывания. Нужен рендер — запускать без --headless (в облаке — через xvfb-run).
## Картинки — в user://reflection_snapshots/.

const OUT := "user://reflection_snapshots"
## Участки: имя и x героя.
const SPOTS := {"1_start": 4.0, "2_slide": 64.0, "3_panes": 80.0, "4_gaps": 140.0, "5_meteors": 185.0, "6_slide": 273.0}

var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	var main: Node = load("res://main.tscn").instantiate()
	main.get_node("RoomManager").start_room = &"reflection_run"
	get_tree().root.add_child.call_deferred(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.0).timeout
	var rooms := main.get_node("RoomManager") as RoomManager
	_player = main.get_node("Player") as Player
	_player.health.max_health = 99999.0
	_player.health.heal(99999.0)
	# Программный рендер не знает прозрачности узла: капсулу и клинок-призрак убираем со слоёв.
	for node in _player.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).transparency >= 0.99:
			(node as GeometryInstance3D).layers = 0
	var run := RunLevel.of(rooms.current_room)
	run.set_physics_process(false)
	for spot: String in SPOTS:
		var x: float = SPOTS[spot]
		# Глыбы прилетают, когда герой подходит: встать над ближайшей и подождать.
		_player.teleport(Vector3(x, 3.0, 0.0))
		_player.frozen = true
		rooms.camera_rig.snap_to_target()
		await get_tree().create_timer(1.4).timeout
		await _shot(spot)
		_player.frozen = false
	# Стена схлопывания догоняет.
	run.set_physics_process(true)
	_player.teleport(Vector3(40.0, 1.5, 0.0))
	_player.frozen = true
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(2.5).timeout
	await _shot("7_collapse")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
