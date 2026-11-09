extends Node
## Быстрая проверка разбора всех скриптов проекта — секунды вместо смоук-теста: тест после ошибки
## разбора не выходит, а висит до timeout. Запускается как сцена (нужны автозагрузки):
## timeout 120 "/c/Program Files/Godot/Godot.exe" --headless --path . res://tools/check_scripts.tscn
## В конце — «SCRIPTS: OK (N)» или список сломанных и код выхода 1.

const SKIP := ["res://.godot", "res://art", "res://addons"]


func _ready() -> void:
	var scripts: Array[String] = []
	_collect("res://", scripts)
	var broken: Array[String] = []
	for path in scripts:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate() and not script.is_abstract():
			broken.append(path)
	if broken.is_empty():
		print("SCRIPTS: OK (%d)" % scripts.size())
	else:
		for path in broken:
			print("BROKEN: ", path)
		print("SCRIPTS: FAIL (%d of %d)" % [broken.size(), scripts.size()])
	get_tree().quit(1 if broken.size() > 0 else 0)


func _collect(dir: String, into: Array[String]) -> void:
	for skip: String in SKIP:
		if dir.begins_with(skip):
			return
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			into.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), into)
