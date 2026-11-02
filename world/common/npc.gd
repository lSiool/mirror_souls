class_name Npc
extends Interactable
## Житель, с которым можно поговорить: реплики идут по кругу. После важного события — другие.
## Может один раз отдать оружие. Заглушка до настоящих диалогов (Dialogic или Ink, §9).

@export var npc_name := "Житель"
@export var lines := PackedStringArray()
## Когда стоит этот флаг, вместо lines звучат lines_after.
@export var after_flag: StringName
@export var lines_after := PackedStringArray()
## Подарок при первом разговоре: оружие и флаг «уже отдал»; пусто — без подарка.
@export var gift_weapon: StringName
@export var gift_flag: StringName
@export var gift_line := ""
## Подарок-предмет вместо оружия (GameState.add_item), тоже один раз — по gift_flag.
@export var gift_item: StringName
## Есть только когда стоит этот флаг (Травница — после спасения). Пусто — всегда.
@export var appear_flag: StringName
@export var look_color := Color(0.3, 0.26, 0.22)
## На сколько фигура стоит глубже плоскости героя.
@export var look_depth := 1.2

var _next := 0


func _ready() -> void:
	super()
	if appear_flag != &"" and not GameState.has_flag(appear_flag):
		queue_free()
		return
	prompt = "Поговорить: %s" % npc_name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.4, 3.0)
	shape.shape = box
	shape.position.y = 1.2
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = look_color
	var body := CapsuleMesh.new()
	body.radius = 0.36
	body.height = 1.7
	body.material = material
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = body
	body_mesh.position = Vector3(0.0, 0.85, -look_depth)
	add_child(body_mesh)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.material = material
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = head
	head_mesh.position = Vector3(0.0, 1.85, -look_depth)
	add_child(head_mesh)


func interact(by: Player) -> void:
	if (gift_weapon != &"" or gift_item != &"") and not GameState.has_flag(gift_flag):
		GameState.set_flag(gift_flag)
		if gift_weapon != &"":
			by.equip(gift_weapon)
			Events.item_found.emit(gift_weapon)
		else:
			GameState.add_item(gift_item)
			Events.item_found.emit(gift_item)
		_say(gift_line)
		return
	var pool := lines_after if after_flag != &"" and GameState.has_flag(after_flag) else lines
	if pool.is_empty():
		return
	_say(pool[_next % pool.size()])
	_next += 1


func _say(text: String) -> void:
	Events.message.emit("%s: %s" % [npc_name, text])
