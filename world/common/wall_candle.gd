class_name WallCandle
extends Interactable
## Свеча в нише стены катакомб (§8.13): тьму разгоняют свечи, которые герой зажигает по пути.
## Зажечь можно только фонарём фонарщика (Player.LANTERN_ITEM); зажжённая горит и после смерти —
## флаг в сейве, путь светлеет, как открытые срезки. Вид — заглушка graybox: свечи на железной полке.

const FLAME_COLOR := Color(1.0, 0.62, 0.26)
const LIGHT_COLOR := Color(1.0, 0.66, 0.34)
const UNLIT_TEXT := "Свеча. Нечем зажечь: нужен огонь."

## Флаг «зажжена» — у каждой свечи свой (генератор: candle_<комната>_<имя>).
@export var flag: StringName
@export var light_energy := 1.6
@export var light_range := 7.0
## Сколько свечей на полке.
@export var count := 3
## Где полка со свечами от точки узла: узел — на полу в плоскости героя (там зона взаимодействия),
## полка — в нише стены позади.
@export var shelf := Vector3(0.0, 1.3, -1.7)

var lit := false
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	super()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.0, 2.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.0)
	add_child(shape)
	_build()
	_set_lit(GameState.has_flag(flag))


func interact(player: Player) -> void:
	if lit:
		return
	if not player.has_lantern():
		Events.message.emit(UNLIT_TEXT)
		return
	# Фонарь убран — герой достаёт его, чтобы поджечь фитиль.
	if not player.lantern_out():
		player.show_lantern(true)
	GameState.set_flag(flag)
	_set_lit(true)


func _set_lit(on: bool) -> void:
	lit = on
	enabled = not on
	prompt = "Зажечь свечу"
	for flame in _flames:
		flame.visible = on
	_light.visible = on
	set_process(on)


func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = light_energy * (1.0 + 0.08 * sin(_t * 11.0 + position.x) + 0.05 * sin(_t * 4.1))


func _build() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.08, 0.075, 0.075)
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.72, 0.66, 0.52)
	var fire := StandardMaterial3D.new()
	fire.albedo_color = FLAME_COLOR
	fire.emission_enabled = true
	fire.emission = FLAME_COLOR
	fire.emission_energy_multiplier = 6.0
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(Vector3(0.18 * count + 0.2, 0.05, 0.3), iron, shelf + Vector3(0.0, -0.03, 0.0))
	for i in count:
		var h := 0.18 + (i % 2) * 0.1
		var x := (i - (count - 1) * 0.5) * 0.18
		_box(Vector3(0.06, h, 0.06), wax, shelf + Vector3(x, h * 0.5, 0.0))
		var flame := _box(Vector3(0.035, 0.07, 0.035), fire, shelf + Vector3(x, h + 0.05, 0.0))
		_flames.append(flame)
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.position = shelf + Vector3(0.0, 0.4, 0.7)
	add_child(_light)


func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mesh.mesh = box
	mesh.position = pos
	add_child(mesh)
	return mesh
