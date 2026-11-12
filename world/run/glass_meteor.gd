class_name GlassMeteor
extends Hitbox
## Толстый обломок, летящий навстречу герою в нестабильном отражении (§8.11): плечом его не
## пробить. Задел — ранит и отбрасывает назад, скорость потеряна. Уходят от него прыжком,
## перекатом или просто не подставляясь. Срывается с места, когда герой подошёл на launch_dist.

const SHADER := preload("res://effects/shaders/pearl_glass.gdshader")

@export var size := Vector3(1.5, 1.5, 1.5)
## Скорость полёта (м/с): навстречу герою — минус по x.
@export var fly := Vector3(-11.0, 0.0, 0.0)
## Герой ближе этого по x — обломок полетел.
@export var launch_dist := 34.0
@export var hit_damage := 16.0
@export var hit_knockback := 10.0

var flying := false
var _player: Player
var _look: MeshInstance3D
var _spin := Vector3.ZERO


func _ready() -> void:
	super()
	add_to_group(&"glass_meteor")
	collision_layer = 0
	collision_mask = 1 << 1
	damage = hit_damage
	knockback = hit_knockback
	# Сбивает всегда: это глыба, а не тычок.
	heavy = true
	var shape := BoxShape3D.new()
	shape.size = size * 0.85
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var seed_value := float(absi(hash(name)) % 1000) / 1000.0
	material.set_shader_parameter(&"seed", seed_value)
	material.set_shader_parameter(&"alpha", 0.85)
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.left_to_right = 0.15 + seed_value * 0.7
	mesh.material = material
	_look = MeshInstance3D.new()
	_look.mesh = mesh
	add_child(_look)
	_spin = Vector3(1.3 + seed_value, 0.7, 2.1 - seed_value * 1.5)
	active = true


func _physics_process(delta: float) -> void:
	super(delta)
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	if not flying:
		flying = _player.global_position.x > global_position.x - launch_dist
		return
	global_position += fly * delta
	_look.rotation += _spin * delta
	# Пролетел мимо — может ударить снова того, кто вернулся под него.
	if not _already_hit.is_empty() and get_overlapping_areas().is_empty():
		_already_hit.clear()
	if global_position.x < _player.global_position.x - 50.0:
		queue_free()
