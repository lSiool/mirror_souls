extends Node
## Снимки интерфейса из настоящей игры (§8.12): HUD, окно находки, страницы меню осколка.
## Нужен рендер — запускать без --headless:
## "/c/Program Files/Godot/Godot.exe" --path . res://tools/ui/snapshot.tscn
## Картинки — в user://ui_snapshots/ (папка пользовательских данных Godot).

const OUT := "user://ui_snapshots"

var _main: Node


func _ready() -> void:
	GameState.saves_enabled = false
	GameState.weapon_id = &"sword"
	GameState.set_flag(&"got_sword")
	GameState.set_flag(&"has_bow")
	GameState.add_item(&"bow_hunter")
	GameState.add_item(&"tempered_glass")
	GameState.add_item(&"tempered_glass")
	GameState.own_weapon(&"stick")
	GameState.own_weapon(&"candlestick")
	GameState.second_weapon_id = &"candlestick"
	GameState.weapon_glass[&"sword"] = 2
	GameState.mastery[&"sword"] = 68.0
	GameState.add_echoes(1240)
	_main = load("res://main.tscn").instantiate()
	_main.get_node("RoomManager").start_room = &"room_001"
	get_tree().root.add_child.call_deferred(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(3.0).timeout
	var rooms := _main.get_node("RoomManager") as RoomManager
	var player := _main.get_node("Player") as Player
	player.equip(&"sword")
	player.add_effect(&"mud")
	player.add_effect(&"regen")
	rooms.hud.popup.queue.clear()
	rooms.hud.popup.dismiss()
	await get_tree().create_timer(0.6).timeout
	await _shot("hud")
	rooms.hud.popup.show_item(&"stick")
	await get_tree().create_timer(0.4).timeout
	await _shot("popup")
	rooms.hud.popup.dismiss()
	rooms.level_menu.open(player, rooms.current_room)
	await get_tree().create_timer(0.4).timeout
	await _shot("menu_root")
	rooms.level_menu.choose(PlayerStats.Param.VIGOR)
	for page in [LevelMenu.Page.LEVEL, LevelMenu.Page.FACETS, LevelMenu.Page.WEAPON, LevelMenu.Page.ITEMS]:
		rooms.level_menu.show_page(page)
		await get_tree().create_timer(0.3).timeout
		await _shot("menu_%s" % LevelMenu.Page.keys()[page].to_lower())
	# Меню паузы (§8.12): тот же LevelMenu в режиме паузы.
	rooms.level_menu.close()
	await get_tree().create_timer(0.3).timeout
	rooms.level_menu.open_pause(player)
	await get_tree().create_timer(0.4).timeout
	await _shot("pause_root")
	for page in [LevelMenu.Page.WEAPON, LevelMenu.Page.SETTINGS]:
		rooms.level_menu.show_page(page)
		await get_tree().create_timer(0.3).timeout
		await _shot("pause_%s" % LevelMenu.Page.keys()[page].to_lower())
	print("snapshots: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, file])
