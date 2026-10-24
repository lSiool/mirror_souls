class_name HeroEcho
extends Interactable
## Отзвук героя на месте последней гибели (GameState.hero_echo): светящийся силуэт без лица,
## с оружием, с которым герой погиб, — лук угадывается в руке, меч на поясе. Контуры то и дело
## распадаются (effects/shaders/hero_echo.gdshader). Коснулся — отзвуки вернулись.
## Не забрал и погиб снова — силуэт исчезает вместе со своими отзвуками.

const SHADER := preload("res://effects/shaders/hero_echo.gdshader")
const COLOR := Color(0.45, 0.72, 1.0)

var _silhouette: Node3D
var _material: ShaderMaterial
var _time := 0.0
var _taken := false


## Силуэт строится из облика героя: копия его фигуры и оружия, только светом.
static func spawn(parent: Node, at: Vector3, player: Player, weapon: StringName, facing: float) -> HeroEcho:
	var echo := HeroEcho.new()
	parent.add_child(echo)
	echo.global_position = at
	echo._build(player, weapon, facing)
	return echo


func _ready() -> void:
	super()
	prompt = "Вернуть отзвуки"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 2.2, 2.0)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position.y = 1.2
	add_child(light)


func _build(player: Player, weapon: StringName, facing: float) -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_silhouette = player.make_silhouette(weapon)
	add_child(_silhouette)
	_silhouette.position = Vector3.ZERO
	_silhouette.rotation.y = 0.0 if facing > 0.0 else PI
	for mesh: MeshInstance3D in _silhouette.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _material


func interact(_by: Player) -> void:
	if _taken:
		return
	_taken = true
	enabled = false
	GameState.take_hero_echo()
	Sfx.play(&"glass_glint", global_position + Vector3(0.0, 1.0, 0.0))
	HitSpark.spawn(get_parent(), global_position + Vector3(0.0, 1.0, 0.3), COLOR, 28)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _material.set_shader_parameter("strength", v), 1.0, 0.0, 0.6)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	if _silhouette and not _taken:
		# Едва заметно покачивается — висит в воздухе, а не стоит.
		_silhouette.position.y = 0.06 + sin(_time * 1.6) * 0.05
