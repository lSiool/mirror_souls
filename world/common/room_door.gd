class_name RoomDoor
extends Interactable
## Дверь в другую комнату. Может быть заперта: условие — флаг мира или пустой от врагов дом.
## Сама никого не переносит: сообщает менеджеру комнат, куда ведёт.

@export var target_room: StringName
## Точка появления в той комнате.
@export var target_spawn: NodePath
@export var open_prompt := "Открыть дверь"
## Что нужно, чтобы дверь открылась: флаг мира. Пусто — не нужен.
@export var required_flag: StringName
## Ещё условия сразу: все флаги должны стоять (Главное Зеркало: босс и все осколки).
@export var required_flags: Array[StringName] = []
## Откроется, только когда в комнате не останется живых врагов; потом открыта навсегда.
@export var needs_clear := false
@export var clear_flag: StringName
@export var locked_text := "Заперто."
## Когда стоит этот флаг, дверь закрыта навсегда: вход на пройденный уровень-забег (§8.11).
@export var closed_flag: StringName
@export var closed_text := "Туда больше нет дороги."
@export var door_size := Vector3(1.3, 2.4, 0.15)
@export var door_color := Color(0.3, 0.2, 0.12)
@export var door_glow := 0.0


func _ready() -> void:
	super()
	prompt = open_prompt
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(door_size.x + 0.6, door_size.y, 2.4)
	shape.shape = box
	shape.position = Vector3(0.0, door_size.y * 0.5, 0.3)
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var door := BoxMesh.new()
	door.size = door_size
	var wood := StandardMaterial3D.new()
	wood.albedo_color = door_color
	if door_glow > 0.0:
		wood.emission_enabled = true
		wood.emission = door_color
		wood.emission_energy_multiplier = door_glow
	door.material = wood
	mesh.mesh = door
	mesh.position = Vector3(0.0, door_size.y * 0.5, -0.9)
	add_child(mesh)


func is_locked() -> bool:
	if required_flag != &"" and not GameState.has_flag(required_flag):
		return true
	for flag in required_flags:
		if not GameState.has_flag(flag):
			return true
	if not needs_clear or GameState.has_flag(clear_flag):
		return false
	for enemy: Dummy in get_tree().get_nodes_in_group("enemy"):
		if enemy.state != Dummy.State.DEAD:
			return true
	GameState.set_flag(clear_flag)
	return false


func interact(_by: Player) -> void:
	if closed_flag != &"" and GameState.has_flag(closed_flag):
		Events.message.emit(closed_text)
	elif is_locked():
		Events.message.emit(locked_text)
	else:
		Events.door_used.emit(self)
