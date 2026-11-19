class_name Lava
extends Area3D
## Лава Пекла (§8.13): не убивает касанием, а сжигает — пока герой в ней, здоровье быстро тает (доля от
## максимума в секунду, DAMAGE_SHARE), и он горит (Statuses.BURNING) ещё немного после. Доспех с сопротивлением
## огню (ArmorData, GameState.armor_resist) снимает ту же долю урона лавы и горения. Под лавой — дно: в неглубокой
## протоке можно пробрести, из реки — выбраться на камни. Отзвук героя, сгоревшего в лаве, остаётся на последней
## твёрдой земле (covers — как у кольев). Враг в лаве горит так же. Поверхность — шейдер `lava.gdshader`:
## тёмная корка, светящиеся трещины, медленное течение; над ней тёплый свет. Узел стоит серединой поверхности.

const LAYER_PLAYER := 1 << 1
const LAYER_ENEMY := 1 << 2
const SHADER := preload("res://world/hazards/lava.gdshader")
const GLOW := Color(1.0, 0.42, 0.12)
## Какую долю максимума здоровья лава сжигает за секунду без защиты: с полного — около трёх секунд.
const DAMAGE_SHARE := 0.3
## Сколько секунд герой ещё горит, выбравшись из лавы.
const AFTERBURN := 2.0

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


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			var player := body as Player
			if player.is_dead():
				continue
			var share := DAMAGE_SHARE * (1.0 - GameState.armor_resist(&"fire"))
			player.health.take_damage(player.health.max_health * share * delta)
			player.statuses.apply(Statuses.BURNING, AFTERBURN)
		elif body is Dummy:
			var enemy := body as Dummy
			if enemy.state == Dummy.State.DEAD:
				continue
			enemy.health.take_damage(enemy.health.max_health * DAMAGE_SHARE * delta)
			enemy.statuses.apply(Statuses.BURNING, AFTERBURN)


## Шипение и вспышка, когда кто-то ступил в лаву.
func _on_body_entered(body: Node3D) -> void:
	if body is Player or body is Dummy:
		Sfx.play(&"lava_sizzle", body.global_position)
		HitSpark.spawn(get_parent(), body.global_position + Vector3(0.0, 0.3, 0.3), GLOW, 10)


## Над лавой ли эта точка: отзвук героя в лаве не оставляем (Player._on_hazard).
func covers(at: Vector3) -> bool:
	var local := to_local(at)
	return absf(local.x) < size.x * 0.5 + 0.3 and absf(local.z) < size.z * 0.5 and local.y < 0.6 and local.y > -size.y - 0.5
