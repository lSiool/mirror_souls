extends Node
## Снимки приёма вампира «Мышь» (§6.3) в галерее замка: взлёт с плащом-крыльями, вис, пике,
## тёмный взрыв, мышь, замах пике мыши, пролёт, посадка. Нужен рендер — запускать без --headless.
## Картинки — в user://vampire_snapshots/.

const OUT := "user://vampire_snapshots"

var _main: Node
var _player: Player
var _rooms: RoomManager


func _ready() -> void:
	GameState.saves_enabled = false
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _wait(2.0)
	_rooms = _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	_rooms.hud.popup.queue.clear()
	_rooms.hud.popup.dismiss()
	_player.hurtbox.invulnerable = true
	await _rooms.travel(&"castle_gallery", ^"Spawns/PlayerStart")
	await _wait(0.5)
	var vamp := _rooms.current_room.get_node("Objects/Vampire") as Vampire
	vamp.bat_first_delay = 99.0
	_player.teleport(Vector3(vamp.global_position.x - 6.0, vamp.global_position.y + 0.1, 0.0))
	_player.facing = 1.0
	await _wait(0.6)
	vamp.start_bat()
	await _wait(vamp.rise_time * 0.4)
	await _shot("1_rise", vamp)
	await _wait(vamp.rise_time * 0.6 + vamp.hang_time * 0.5)
	await _shot("2_hang_cloak", vamp)
	await _until(vamp, Vampire.Move.DIVE)
	await _wait(0.12)
	await _shot("3_dive", vamp)
	await _until(vamp, Vampire.Move.BURST)
	await _wait(0.06)
	await _shot("4_burst", vamp)
	await _wait(0.25)
	await _shot("5_burst_bat", vamp)
	await _until(vamp, Vampire.Move.BAT_AIM)
	await _wait(vamp.swoop_windup * 0.8)
	await _shot("6_bat_aim", vamp)
	await _until(vamp, Vampire.Move.BAT_SWOOP)
	await _wait(0.3)
	await _shot("7_swoop", vamp)
	await _until(vamp, Vampire.Move.BAT_LAND)
	await _wait(0.4)
	await _shot("8_landing", vamp)
	await _until(vamp, Vampire.Move.NONE)
	await _wait(0.1)
	await _shot("9_human_again", vamp)
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(vamp: Vampire, move: Vampire.Move) -> void:
	for i in 600:
		if vamp.move == move:
			return
		await get_tree().physics_frame


func _shot(shot_name: String, vamp: Vampire) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cam := get_viewport().get_camera_3d()
	var at := cam.unproject_position(vamp.global_position + Vector3(0.0, 1.2, 0.0))
	var half := 300
	var crop := Rect2i(int(at.x) - half, int(at.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var part := img.get_region(crop)
	part.resize(400, 400 * crop.size.y / maxi(crop.size.x, 1), Image.INTERPOLATE_LANCZOS)
	part.save_png("%s/%s.png" % [OUT, shot_name])
