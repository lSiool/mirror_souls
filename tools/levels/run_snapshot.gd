extends Node
## Снимки уровня-забега (§8.11): кадры по участкам горящей деревни, обрушение и герой,
## очнувшийся у осколка. Нужен рендер — запускать без --headless:
## godot --path . res://tools/levels/run_snapshot.tscn  (в облаке — через xvfb-run).
## Картинки — в user://run_snapshots/.

const OUT := "user://run_snapshots"
## Участки: имя и место героя (x, y).
const SPOTS := {"1_fork_hatch": Vector2(45.0, 0.2), "2_greenhouse": Vector2(71.0, 5.2), "3_ravine_slide": Vector2(53.0, -2.6),
	"4_barricade": Vector2(89.5, -5.3), "5_cellar_boards": Vector2(104.0, -5.3), "6_loft_slide": Vector2(150.0, 6.7),
	"7_street_boards": Vector2(174.0, 0.2)}

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
		var at: Vector2 = SPOTS[spot]
		_player.teleport(Vector3(at.x, at.y, 0.0))
		rooms.camera_rig.snap_to_target()
		await get_tree().create_timer(0.7).timeout
		await _shot(spot)
	# Три этажа общим планом: крыши, улица, овраг.
	_player.teleport(Vector3(88.0, 0.2, 0.0))
	rooms.camera_rig.zoom(1.9, 0.0)
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(0.7).timeout
	await _shot("2_floors")
	rooms.camera_rig.zoom(1.0, 0.0)
	# Обрушение: герой на мосту, фронт догоняет.
	run.burn_rate = 0.0
	run.set_physics_process(true)
	_player.teleport(Vector3(229.5, 0.2, 0.0))
	rooms.camera_rig.snap_to_target()
	await get_tree().create_timer(3.4).timeout
	await _shot("8_collapse")
	# Гибель: очнулся у следующего осколка.
	GameState.echoes = 300
	_player.health.take_damage(INF)
	await get_tree().create_timer(RoomManager.DEATH_HOLD + RoomManager.RUN_WAKE_DARK + RoomManager.RUN_WAKE_FADE + 1.5).timeout
	await _shot("9_wake")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
