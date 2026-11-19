class_name FlagLever
extends Interactable
## Рычаг или ворот, который один раз ставит флаг мира (§8.13): ворот старой клети в Пекле опускает клеть
## под провалом — короткий путь наверх, к копям. Повёрнутый остаётся повёрнутым: флаг в сейве.

@export var flag: StringName
@export var lever_prompt := "Повернуть рычаг"
## Реплика, когда повернули.
@export var line := ""

var _handle: MeshInstance3D


func _ready() -> void:
	super()
	prompt = lever_prompt
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.4, 2.4)
	shape.shape = box
	shape.position.y = 1.2
	add_child(shape)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09, 0.09, 0.1)
	iron.metallic = 0.4
	iron.roughness = 0.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.12, 0.09, 0.07)
	wood.roughness = 0.9
	var drum := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.35
	cylinder.bottom_radius = 0.35
	cylinder.height = 1.0
	cylinder.material = wood
	drum.mesh = cylinder
	drum.rotation.x = PI * 0.5
	drum.position = Vector3(0.0, 0.9, -1.0)
	add_child(drum)
	_handle = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.08, 0.9, 0.08)
	bar.material = iron
	_handle.mesh = bar
	_handle.position = Vector3(0.0, 0.9, -0.45)
	add_child(_handle)
	_show(GameState.has_flag(flag))


func interact(_by: Player) -> void:
	if GameState.has_flag(flag):
		return
	GameState.set_flag(flag)
	if line != "":
		Events.message.emit(line)
	_show(true)


func _show(done: bool) -> void:
	enabled = not done
	_handle.rotation.z = -1.2 if done else 0.4
