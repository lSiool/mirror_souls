extends Node
## Снимки Кузнеца на манекене (§3.3, §6.3) в его комнате: сидит на камне, встал, замах, удар,
## на колене (сбитая стойкость), вторая фаза. Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/characters/boss_snapshot.tscn
## Картинки — в user://boss_snapshots/.

const OUT := "user://boss_snapshots"

var _main: Node
var _player: Player
var _rooms: RoomManager


func _ready() -> void:
	GameState.saves_enabled = false
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _wait(3.0)
	_rooms = _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	_rooms.hud.popup.queue.clear()
	_rooms.hud.popup.dismiss()
	_player.hurtbox.invulnerable = true
	await _rooms.travel(&"cursed_village", ^"Spawns/FromSwamp")
	await _wait(1.0)
	var smith := _rooms.current_room.get_node("Objects/Blacksmith") as Blacksmith
	_player.teleport(Vector3(smith.global_position.x - 9.0, smith.global_position.y + 0.1, 0.0))
	await _wait(0.5)
	await _shot("1_seated", smith)
	_player.teleport(Vector3(smith.global_position.x - 5.0, smith.global_position.y + 0.1, 0.0))
	await _wait(2.6)
	await _shot("2_rising", smith)
	await _wait(1.2)
	await _shot("3_standing", smith)
	# Удары: замах сверху, удар в пол, боковой.
	smith.chase_speed = 0.0
	smith._begin([Blacksmith.Blow.SLAM], 1.0)
	await _wait(smith.windup_time * 0.8)
	await _shot("4_slam_windup", smith)
	await _wait(smith.windup_time * 0.2 + smith.attack_time * 0.9)
	await _shot("5_slam_hit", smith)
	await _wait(1.5)
	smith._set_state(Dummy.State.OFF_BALANCE)
	await _wait(0.5)
	await _shot("6_off_balance_kneel", smith)
	smith._set_state(Dummy.State.CHASE)
	await _wait(1.0)
	smith._begin([Blacksmith.Blow.SWEEP], 1.0)
	await _wait(smith.windup_time * 0.9)
	await _shot("7_sweep_windup", smith)
	await _wait(1.6)
	smith.health.take_damage(smith.health.current - smith.health.max_health * 0.5)
	smith._transition()
	await _wait(0.6)
	await _shot("8_phase2_kneel", smith)
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String, foe: Node3D) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cam := get_viewport().get_camera_3d()
	var at := cam.unproject_position(foe.global_position + Vector3(0.0, 1.5, 0.0))
	var half := 260
	var crop := Rect2i(int(at.x) - half, int(at.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var part := img.get_region(crop)
	part.resize(300, 300 * crop.size.y / maxi(crop.size.x, 1), Image.INTERPOLATE_LANCZOS)
	part.save_png("%s/%s.png" % [OUT, shot_name])
