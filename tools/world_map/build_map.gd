extends Node
## Снимает форму всех комнат карты (MapShapes.extract) в systems/world_map/map_shapes.tres (§8.13).
## Запускать после правки комнат или генераторов:
##   godot --headless --path . res://tools/world_map/build_map.tscn
## Комната ставится в дерево на кадр: стекло и рушащиеся куски строят коллизию в _ready. Сценки комнат
## (пробуждение в хижине, оборотень на площади) ищут героя и пишут ошибки — на снятую форму это не влияет.


func _ready() -> void:
	GameState.saves_enabled = false
	var shapes := MapShapes.new()
	# Порядок — по имени: файл воспроизводим от запуска к запуску.
	var names: Array[String] = []
	for key: StringName in WorldMap.ROOMS:
		names.append(String(key))
	names.sort()
	for name in names:
		var id := StringName(name)
		var room := (load(RoomManager.ROOM_PATH % id) as PackedScene).instantiate() as Room
		# Мир по умолчанию: деревня после пожара (осколок площади — в AfterFire), обычная реальность.
		room.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(room)
		await get_tree().process_frame
		shapes.rooms[id] = MapShapes.extract(room)
		print("  %s: %d твёрдых, %d стекла, %d лестниц, %d дверей, %d осколков" % [id, shapes.rooms[id]["solids"].size(),
			shapes.rooms[id]["glass"].size(), shapes.rooms[id]["ladders"].size(), shapes.rooms[id]["doors"].size(),
			shapes.rooms[id]["shards"].size()])
		room.free()
	var error := ResourceSaver.save(shapes, MapShapes.PATH)
	print("MAP: %s (%d комнат)" % ["OK" if error == OK else "ERROR %d" % error, shapes.rooms.size()])
	get_tree().quit(0 if error == OK else 1)
