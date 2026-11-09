class_name GlintFlash
extends Node3D
## Блик (§6.2): вспышка отражённого света с навершия посоха. Ослепляет врагов перед героем —
## в пределах reach вперёд и height по высоте. Как ослеплённый переживает свет, решает его класс
## (CreatureKind): слепоту просто вешаем, враг сам знает, слепнуть ли и надолго ли.
## Видно: белая вспышка света, луч-веер вперёд и блёстки, тает за FADE_TIME.

const COLOR := Color(1.0, 0.97, 0.88)
const FADE_TIME := 0.45
const LIGHT_ENERGY := 9.0

## Кого ослепила вспышка (для тестов и HUD).
var blinded: Array[Dummy] = []
var _light: OmniLight3D
var _fan: MeshInstance3D
var _fan_material: StandardMaterial3D
var _age := 0.0


## Вспышка в точке at (навершие посоха), герой смотрит в facing. power — множитель Интеллекта.
static func flash(parent: Node, at: Vector3, facing: float, spell: SpellData, power := 1.0) -> GlintFlash:
	var glint := GlintFlash.new()
	parent.add_child(glint)
	glint.global_position = at
	glint._build(facing, spell)
	glint._blind(at, facing, spell, power)
	return glint


func _build(facing: float, spell: SpellData) -> void:
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = spell.reach
	_light.position = Vector3(0.0, 0.0, 0.6)
	add_child(_light)
	# Веер света вперёд: плоский клин от навершия, полупрозрачный, без теней.
	_fan_material = StandardMaterial3D.new()
	_fan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fan_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fan_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fan_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fan_material.albedo_color = Color(COLOR, 0.55)
	var fan := ImmediateMesh.new()
	fan.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _fan_material)
	var tip := Vector3.ZERO
	var far := spell.reach
	var spread := spell.height * 0.5
	fan.surface_add_vertex(tip)
	fan.surface_add_vertex(Vector3(far * facing, spread, 0.0))
	fan.surface_add_vertex(Vector3(far * facing, -spread, 0.0))
	fan.surface_end()
	_fan = MeshInstance3D.new()
	_fan.mesh = fan
	_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fan)
	HitSpark.spawn(get_parent(), global_position, COLOR, 24)
	Sfx.play(&"glass_glint", global_position, 2.0)


func _blind(at: Vector3, facing: float, spell: SpellData, _power: float) -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Dummy
		if enemy == null or enemy.state == Dummy.State.DEAD:
			continue
		var d := enemy.global_position + Vector3(0.0, enemy.body_height() * 0.5, 0.0) - at
		if signf(d.x) != facing or absf(d.x) > spell.reach or absf(d.y) > spell.height:
			continue
		enemy.statuses.apply(Statuses.BLIND, spell.blind_time)
		if enemy.statuses.has(Statuses.BLIND):
			blinded.append(enemy)


func _process(delta: float) -> void:
	_age += delta
	var k := clampf(1.0 - _age / FADE_TIME, 0.0, 1.0)
	_light.light_energy = LIGHT_ENERGY * k * k
	_fan_material.albedo_color.a = 0.55 * k
	if _age >= FADE_TIME:
		queue_free()
