extends Node
## Снимки реакций на слепоту (§6.2, §6.3) в настоящей игре: у каждого класса врага своя.
## Кадры: враг до слепоты (руки graybox держат оружие), отшатнулся, трёт глаза (ревёт, меркнет).
## Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/characters/blind_snapshot.tscn
## Картинки — в user://blind_snapshots/.

const OUT := "user://blind_snapshots"
## Враг: сцена, класс (пусто — свой) и половина кадра в пикселях.
const FOES := [
	["dummy", -1, 130],
	["dummy", CreatureKind.Kind.VAMPIRE, 130],
	["bandit_heavy", -1, 150],
	["bandit_knife", -1, 150],
	["blacksmith", -1, 230],
	["werewolf", -1, 170],
	["rat", -1, 100],
	["fog_wraith", -1, 120],
]

var _main: Node
var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(3.0).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	_player.teleport(Vector3(-24.0, 0.1, 0.0))
	_player.facing = 1.0
	_player.hurtbox.invulnerable = true
	for soldier in get_tree().get_nodes_in_group("enemy"):
		soldier.queue_free()
	await _wait(0.5)
	for i in FOES.size():
		var spec: Array = FOES[i]
		var foe := (load("res://actors/enemies/%s.tscn" % spec[0]) as PackedScene).instantiate() as Dummy
		foe.dormant = false
		# Стоит лицом к герою и не нападает: снимаем только позы.
		foe.facing = -1.0
		foe.patrol_speed = 0.0
		foe.chase_speed = 0.0
		foe.detect_range = 0.0
		foe.back_sense_range = 0.0
		if spec[1] >= 0:
			foe.creature = spec[1]
		if foe is Werewolf:
			(foe as Werewolf).gone_flag = &"snapshot_never_set"
		if foe is Blacksmith:
			(foe as Blacksmith).boss_flag = &"snapshot_never_set"
		rooms.current_room.add_child(foe)
		foe.global_position = Vector3(-20.5, 0.1 if not foe is Bat else 2.2, 0.0)
		if foe is Bat:
			(foe as Bat)._awake = true
		var shot := "%d_%s%s" % [i + 1, spec[0], "_vampire" if spec[1] == CreatureKind.Kind.VAMPIRE else ""]
		await _wait(1.2)
		await _shot(shot + "_a_before", foe, spec[2])
		foe.statuses.apply(Statuses.BLIND, Statuses.BLIND_TIME)
		await _wait(0.45)
		await _shot(shot + "_b_recoil", foe, spec[2])
		await _wait(0.9)
		await _shot(shot + "_c_blind", foe, spec[2])
		foe.queue_free()
		await _wait(0.3)
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String, foe: Node3D, half: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var cam := get_viewport().get_camera_3d()
	var at := cam.unproject_position(foe.global_position + Vector3(0.0, 1.0, 0.0))
	var crop := Rect2i(int(at.x) - half, int(at.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var part := img.get_region(crop)
	part.resize(300, 300 * crop.size.y / maxi(crop.size.x, 1), Image.INTERPOLATE_LANCZOS)
	part.save_png("%s/%s.png" % [OUT, shot_name])
