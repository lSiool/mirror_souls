class_name ItemPickup
extends Interactable
## Находка на земле: оружие, способность или предмет. Подобрав, герой больше её не встретит.

## Оружие, которое герой берёт в руку; пусто — не оружие.
@export var weapon_id: StringName
## Предмет в GameState; пусто — не предмет.
@export var item_id: StringName
## Флаг «подобрано»: мир запомнит. Он же может быть способностью (has_bow).
@export var flag: StringName
@export var pickup_prompt := "Подобрать"
## Вид заглушки на земле.
## Отзвуки в находке (отзвук босса берут касанием).
@export var echoes := 0
## Появится, только когда этот флаг поставлен: отзвук босса — после победы.
@export var appear_flag: StringName
@export var look_size := Vector3(1.0, 0.1, 0.1)
@export var look_color := Color(0.4, 0.28, 0.16)


func _ready() -> void:
	super()
	if GameState.has_flag(flag):
		queue_free()
		return
	prompt = pickup_prompt
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.0, 2.0)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var stick := BoxMesh.new()
	stick.size = look_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = look_color
	stick.material = mat
	mesh.mesh = stick
	mesh.position = Vector3(0.0, look_size.y * 0.5 + 0.02, 0.0)
	mesh.rotation.y = 0.35
	add_child(mesh)
	# Слабый отблеск: находку видно на тёмной земле.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 0.5
	light.omni_range = 1.8
	light.position.y = 0.5
	add_child(light)
	if appear_flag != &"" and not GameState.has_flag(appear_flag):
		visible = false
		enabled = false
	else:
		set_process(false)


func _process(_delta: float) -> void:
	if GameState.has_flag(appear_flag):
		visible = true
		enabled = true
		set_process(false)


func interact(by: Player) -> void:
	GameState.set_flag(flag)
	if echoes > 0:
		GameState.add_echoes(echoes)
	if weapon_id != &"":
		by.equip(weapon_id)
		Events.item_found.emit(weapon_id)
	elif item_id != &"":
		GameState.add_item(item_id)
	else:
		Events.item_found.emit(flag)
	enabled = false
	queue_free()
