class_name Lava
extends Area3D
## Лава Пекла (§8.13): смертельна, как пропасть, — коснулся поверхности, и всё; отзвук героя остаётся на последней
## твёрдой земле, как при падении. Враг, упавший в лаву, тоже сгорает. Поверхность — шейдер `lava.gdshader`:
## тёмная корка, светящиеся трещины, медленное течение; над ней тёплый свет. Узел стоит серединой поверхности.

const LAYER_PLAYER := 1 << 1
const LAYER_ENEMY := 1 << 2
const SHADER := preload("res://world/hazards/lava.gdshader")
const GLOW := Color(1.0, 0.42, 0.12)

## Ширина по x, толщина зоны вниз от поверхности, глубина по z.
@export var size := Vector3(6.0, 1.0, 4.4)
## Свет над лавой; 0 — без света (когда лава вдали и света хватает).
@export var glow_energy := 1.6


func _ready() -> void:
	add_to_group(&"hazard")
	collision_layer = 0
	collision_mask = LAYER_PLAYER | LAYER_ENEMY
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = -size.y * 0.5 + 0.05
	add_child(shape)
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	plane.material = material
	surface.mesh = plane
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	if glow_energy > 0.0:
		var light := OmniLight3D.new()
		light.light_color = GLOW
		light.light_energy = glow_energy
		light.omni_range = maxf(size.x * 0.75, 5.0)
		light.position = Vector3(0.0, 1.2, minf(size.z * 0.5, 2.2) * 0.5)
		add_child(light)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_dead():
		(body as Player).health.take_damage(INF)
	elif body is Dummy and (body as Dummy).state != Dummy.State.DEAD:
		(body as Dummy).health.take_damage(INF)
