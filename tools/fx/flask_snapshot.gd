extends Node
## Снимки эффектов склянок и огня (§6.2) из настоящей игры: огненная лужа и костёр, облако яда,
## кислота и смола, святая вода с крестом, взрыв смолы. Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/fx/flask_snapshot.tscn
## Картинки — в user://fx_snapshots/ (папка пользовательских данных Godot).

const OUT := "user://fx_snapshots"

var _main: Node
var _player: Player
var _room: Node3D


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"has_bow")
	GameState.add_item(&"fire_arrow", 5)
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(3.0).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	_room = rooms.current_room
	_player.equip(&"sword")
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	var at := Vector3(-21.0, 0.1, 0.0)
	_player.teleport(at)
	_player.facing = 1.0
	await _wait(0.5)

	var spot := FireSpot.new()
	_room.add_child(spot)
	spot.global_position = at + Vector3(-3.0, -0.1, -1.0)
	_zone(&"fire_flask", at + Vector3(2.5, 0.0, 0.0))
	await _wait(1.2)
	await _shot("fire")
	_clear()

	_zone(&"poison_flask", at + Vector3(2.5, 0.4, 0.0))
	await _wait(1.5)
	await _shot("poison")
	_clear()

	_zone(&"acid_flask", at + Vector3(1.8, 0.0, 0.0))
	_zone(&"tar_flask", at + Vector3(4.2, 0.0, 0.0))
	await _wait(0.6)
	await _shot("acid_tar")

	TarBlast.explode(_room, at + Vector3(4.2, 0.3, 0.0))
	await _wait(0.12)
	await _shot("tar_blast")
	_clear()

	_zone(&"holy_flask", at + Vector3(2.5, 0.0, 0.0))
	HolyCross.spawn(_room, at + Vector3(2.5, -0.1, 0.0))
	await _wait(0.33)
	await _shot("holy")
	_clear()
	spot.queue_free()
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _zone(id: StringName, at: Vector3) -> void:
	var item := ConsumableData.by_id(id)
	FlaskZone.spawn(_room, at, item)
	HitSpark.spawn(_room, at, item.burst_color, 30)


func _clear() -> void:
	for node in _room.find_children("*", "", true, false):
		if node is FlaskZone:
			node.queue_free()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, file])
