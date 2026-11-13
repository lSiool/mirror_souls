class_name ItemPickup
extends Interactable
## Находка на земле: оружие, способность или предмет. Подобрав, герой больше её не встретит.
## Тёплый пульсирующий блик — язык «это можно взять» на всю игру (§8.9).

const GLINT_COLOR := Color(1.0, 0.62, 0.3)
const GLINT_PERIOD := 1.6

## Оружие, которое герой берёт в руку; пусто — не оружие.
@export var weapon_id: StringName
## Предмет в GameState; пусто — не предмет.
@export var item_id: StringName
## Сколько штук предмета в находке (связка кольев, пачка ножей).
@export var item_amount := 1
## Заклинание, которое находка учит (§6.2): посох «помнит» Блик. Пусто — не учит.
@export var spell_id: StringName
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
## Поворот и сдвиг заглушки: брусок можно прислонить к поленнице.
@export var look_rotation := Vector3(0.0, 0.35, 0.0)
@export var look_offset := Vector3.ZERO
## Что герой говорит, подобрав.
@export var pickup_line := ""

var _mat: StandardMaterial3D
var _light: OmniLight3D
var _t := 0.0


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
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = look_color
	_mat.emission_enabled = true
	_mat.emission = GLINT_COLOR
	stick.material = _mat
	mesh.mesh = stick
	mesh.position = look_offset + Vector3(0.0, look_size.y * 0.5 + 0.02, 0.0)
	mesh.rotation = look_rotation
	add_child(mesh)
	# Отблеск: находку видно на тёмной земле.
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.55)
	_light.omni_range = 1.8
	_light.position = look_offset + Vector3(0.0, 0.5, 0.3)
	add_child(_light)
	_glint(0.0)
	if appear_flag != &"" and not GameState.has_flag(appear_flag):
		visible = false
		enabled = false


func _process(delta: float) -> void:
	if not enabled and GameState.has_flag(appear_flag):
		visible = true
		enabled = true
	_t += delta
	_glint(_t)


## Блик дышит: свечение заглушки и отблеск разгораются и гаснут.
func _glint(t: float) -> void:
	var k := 0.5 + 0.5 * sin(t * TAU / GLINT_PERIOD)
	_mat.emission_energy_multiplier = 0.15 + 0.65 * k
	_light.light_energy = 0.35 + 0.45 * k


func interact(by: Player) -> void:
	GameState.set_flag(flag)
	if pickup_line != "":
		Events.message.emit(pickup_line)
	if echoes > 0:
		GameState.add_echoes(echoes)
	if spell_id != &"":
		GameState.learn_spell(spell_id)
	if weapon_id != &"":
		by.equip(weapon_id)
		Events.item_found.emit(weapon_id)
		if spell_id != &"":
			Events.item_found.emit(spell_id)
	elif item_id != &"":
		GameState.add_item(item_id, item_amount)
	else:
		Events.item_found.emit(flag)
	enabled = false
	queue_free()
