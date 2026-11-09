extends Node
## Снимки манекена героя в настоящей игре (§3.3): стойка, бег, кувырок, удары серии, блок.
## Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/characters/hero_snapshot.tscn
## Картинки — в user://hero_snapshots/.

const OUT := "user://hero_snapshots"

var _main: Node
var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	GameState.add_item(GameState.SHIELD_ITEM)
	GameState.add_item(&"bow_hunter")
	GameState.own_weapon(&"candlestick")
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(3.0).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	_player.equip(&"sword")
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	_player.teleport(Vector3(-21.0, 0.1, 0.0))
	_player.facing = 1.0
	await _wait(0.8)
	await _shot("idle")
	Input.action_press("move_right")
	await _wait(0.6)
	await _shot("run")
	Input.action_release("move_right")
	await _wait(0.5)
	# Удары серии: кадр в активном окне каждой стадии.
	for i in 3:
		Input.action_press("attack")
		await _wait(0.05)
		Input.action_release("attack")
		var step := _player.weapon.combo[i]
		await _wait(step.active_from + 0.03)
		await _shot("attack_%d" % (i + 1))
		await _wait(step.chain_from - step.active_from - 0.05)
	await _wait(1.0)
	# Прыжок и удар в воздухе: вертикальный снизу, ноги в позе прыжка.
	Input.action_press("jump")
	await _wait(0.2)
	await _shot("jump")
	Input.action_press("attack")
	await _wait(0.05)
	Input.action_release("attack")
	await _wait(_player.weapon.combo[0].active_from + 0.03)
	await _shot("jump_attack")
	Input.action_release("jump")
	await _wait(1.0)
	Input.action_press("roll")
	await _wait(0.15)
	await _shot("roll")
	Input.action_release("roll")
	await _wait(1.0)
	Input.action_press("block")
	await _wait(0.4)
	await _shot("block")
	Input.action_release("block")
	await _wait(0.4)
	Input.action_press("shoot")
	await _wait(0.6)
	await _shot("bow")
	Input.action_release("shoot")
	await _wait(0.8)
	# Двуручное: щит за спиной.
	_player.equip(&"candlestick")
	await _wait(0.5)
	await _shot("back")
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	# Кадр вокруг героя, крупно.
	var cam := get_viewport().get_camera_3d()
	var at := cam.unproject_position(_player.global_position + Vector3(0.0, 0.9, 0.0))
	var size := img.get_size()
	var half := 150
	var crop := Rect2i(int(at.x) - half, int(at.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, size))
	var part := img.get_region(crop)
	part.resize(crop.size.x * 2, crop.size.y * 2, Image.INTERPOLATE_LANCZOS)
	part.save_png("%s/%s.png" % [OUT, shot_name])
