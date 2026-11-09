extends Node
## Снимки Блика (§6.2) в галерее замка: посох в руке, каст, вспышка и ослеплённый вампир,
## HUD с полосой маны и активным заклинанием. Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/fx/glint_snapshot.tscn
## Картинки — в user://glint_snapshots/.

const OUT := "user://glint_snapshots"

var _main: Node
var _player: Player


func _ready() -> void:
	GameState.saves_enabled = false
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"castle_gallery"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _wait(3.0)
	var rooms := _main.get_node("RoomManager") as RoomManager
	_player = _main.get_node("Player") as Player
	_player.hurtbox.invulnerable = true
	_player.equip(&"staff")
	GameState.learn_spell(&"glint")
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	for i in 12:
		_player.stats.add_point(PlayerStats.Param.MEMORY)
	_player.restore()
	var vampire := rooms.current_room.get_node("Objects/Vampire") as Vampire
	vampire.chase_speed = 0.0
	vampire.detect_range = 0.0
	_player.teleport(Vector3(vampire.global_position.x - 3.0, 0.1, 0.0))
	_player.facing = 1.0
	await _wait(1.0)
	await _shot("1_staff_ready")
	Input.action_press("attack")
	await _wait(0.05)
	Input.action_release("attack")
	await _wait(0.3)
	await _shot("2_cast")
	await _wait(0.1)
	await _shot("3_flash")
	await _wait(0.9)
	await _shot("4_vampire_disoriented")
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Кадр целиком, с HUD, в половину размера.
func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	img.save_png("%s/%s.png" % [OUT, shot_name])
