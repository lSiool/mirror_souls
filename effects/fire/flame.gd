class_name Flame
extends MeshInstance3D
## Язык пламени (§2, без текстур): квад с процедурным шейдером flame.gdshader. Из таких языков
## собраны костры (FireSpot), огненная лужа склянки, наконечник огненной стрелы и огонь духа
## на молоте Кузнеца. Цвета — палитрой (PALETTES), у каждого языка свой узор шума.

const SHADER := preload("res://effects/fire/flame.gdshader")
## Палитра: [ядро, пламя, кончики].
const PALETTES := {
	&"fire": [Color(1.0, 0.8, 0.4), Color(1.0, 0.4, 0.07), Color(0.5, 0.06, 0.015)],
	&"spirit": [Color(0.92, 0.85, 1.0), Color(0.55, 0.3, 1.0), Color(0.18, 0.05, 0.4)],
}

static var _materials := {}

## Угасание: 1 — горит в полную силу, 0 — погас.
var fade := 1.0:
	set(value):
		fade = value
		set_instance_shader_parameter(&"fade", value)


## Общий материал палитры: им же красят частицы-языки (Кузнец).
static func material(palette: StringName = &"fire") -> ShaderMaterial:
	if not _materials.has(palette):
		var colors: Array = PALETTES[palette]
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter(&"core_color", colors[0])
		mat.set_shader_parameter(&"flame_color", colors[1])
		mat.set_shader_parameter(&"tip_color", colors[2])
		_materials[palette] = mat
	return _materials[palette]


## Язык пламени размером size (ширина × высота); основание — в точке узла, растёт вверх.
## surface — поверхность под огнём (flame.gdshader, `surface`): нули — ровная земля, плоский низ; на скате
## крыши — (сдвиг конька по x от центра, высота конька над низом квада, наклон dy/dx).
static func make(size: Vector2, palette: StringName = &"fire", surface := Vector3.ZERO) -> Flame:
	var flame := Flame.new()
	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	flame.mesh = quad
	flame.material_override = material(palette)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.set_instance_shader_parameter(&"seed", randf() * 10.0)
	flame.set_instance_shader_parameter(&"dim", size)
	flame.set_instance_shader_parameter(&"surface", surface)
	return flame
