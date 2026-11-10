extends Node
## Снимки уровня-забега (§8.11): кадры по участкам горящей деревни, обрушение и герой,
## очнувшийся у осколка. Нужен рендер — запускать без --headless:
## godot --path . res://tools/levels/run_snapshot.tscn  (в облаке — через xvfb-run).
## Картинки — в user://run_snapshots/.

const OUT := "user://run_snapshots"
## Участки: имя и x героя.
const SPOTS := {"1_street": 16.0, "2_bridge": 44.5, "3_yard": 70.0, "4_roofs": 91.0, "5_house": 116.0, "6_gate": 140.0}

var _main: Node
var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"run_village"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(2.0).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	var run := RunLevel.of(rooms.current_room)
	# Сначала вид участков: фронт стоит, огонь героя не жжёт.
	run.set_physics_process(false)
	for foe in get_tree().get_nodes_in_group("enemy"):
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	for spot: String in SPOTS:
		var x: float = SPOTS[spot]
		var y := 3.4 if spot == "4_roofs" else 0.2
		_player.teleport(Vector3(x, y, 0.0))
		rooms.camera_rig.snap_to_target()
		await get_tree().create_timer(0.7).timeout
		await _shot(spot)
	# Обрушение: герой на мосту, фронт догоняет.
	run.burn_rate = 0.0
	run.set_physics_process(true)
	_player.teleport(Vector3(57.5, 0.2, 0.0))
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(3.4).timeout
	await _shot("7_collapse")
	# Гибель: очнулся у следующего осколка.
	GameState.echoes = 300
	_player.health.take_damage(INF)
	await get_tree().create_timer(RoomManager.DEATH_HOLD + RoomManager.RUN_WAKE_DARK + RoomManager.RUN_WAKE_FADE + 1.5).timeout
	await _shot("8_wake")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
