class_name Room
extends Node3D
## Комната — только раскладка и данные. Как работают зеркала, знает RoomManager (§11.1).
##
## Соглашения:
## - прямые дети комнаты — контейнеры в начале координат (Geometry, Spawns, Objects…);
##   трансформации отражения двигают объекты внутри контейнеров;
## - узел в группе "<реальность>_only" (например "normal_only", "mirror_only")
##   существует только в этой реальности.

@export var room_id: StringName = &"room_001"
## Ось, относительно которой FlipX зеркалит раскладку.
@export var center_x := 0.0
@export var width := 40.0
## Своё освещение комнаты; пусто — общее из менеджера.
@export var mood: Environment
@export var sun_color := Color(1.0, 0.88, 0.72)
@export var sun_energy := 1.1
## Свет для HUD 0…1 (§8.12): металл и стекло тускнеют в темноте, бликуют на свету.
## Меньше нуля — по освещению комнаты.
@export var hud_light := -1.0
@export_group("Пожар")
## Пока этот флаг не поставлен, комната горит: есть узлы контейнера Burning и своё освещение.
## Когда поставлен — вместо них контейнер AfterFire и обычное освещение. Пусто — комната не горит.
@export var burning_until: StringName
@export var burning_mood: Environment
@export var burning_sun_color := Color(1.0, 0.5, 0.25)
@export var burning_sun_energy := 0.3


func _enter_tree() -> void:
	add_to_group(&"room")


## Насколько светло в комнате для HUD: окружение и солнце, с пожаром — его свет.
func hud_brightness(gain: float) -> float:
	if hud_light >= 0.0:
		return hud_light
	var burning := is_burning()
	var env := burning_mood if burning and burning_mood else mood
	var sun := burning_sun_energy if burning else sun_energy
	var value := sun * 0.15
	if env:
		value += env.ambient_light_color.get_luminance() * env.ambient_light_energy * gain
	return clampf(value, 0.0, 1.0)


func is_burning() -> bool:
	return burning_until != &"" and not GameState.has_flag(burning_until)


## Оставляет облик комнаты, соответствующий пожару. Вызывается до добавления в дерево.
func apply_fire_state() -> void:
	if burning_until == &"":
		return
	var doomed := get_node_or_null(^"AfterFire" if is_burning() else ^"Burning")
	if doomed:
		doomed.free()


## Удаляет узлы, принадлежащие другим реальностям. Вызывается до добавления в дерево.
func apply_reality(reality: StringName) -> void:
	var keep := String(reality) + "_only"
	var doomed: Array[Node] = []
	for node in _descendants(self):
		for group in node.get_groups():
			var g := String(group)
			if g.ends_with("_only") and g != keep:
				doomed.append(node)
				break
	for node in doomed:
		if is_instance_valid(node):
			node.free()


## Объекты раскладки: дети контейнеров.
func layout_objects() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for container in get_children():
		for node in container.get_children():
			if node is Node3D:
				result.append(node)
	return result


func _descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
