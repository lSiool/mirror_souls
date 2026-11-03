class_name FogGate
extends StaticBody3D
## Туманная стена у арены босса, как в Souls: клубящийся занавес, сквозь который не пройти, пока
## бой не кончен. Поднимается за миг, растворяется, когда босс повержен.

const RISE_TIME := 0.8
const FADE_TIME := 1.6
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec4 tint : source_color = vec4(0.55, 0.5, 0.85, 1.0);
uniform float strength = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = UV;
	float slow = fbm(vec2(uv.x * 2.5, uv.y * 1.6 + TIME * 0.22));
	float fast = fbm(vec2(uv.x * 5.0 + TIME * 0.08, uv.y * 3.5 + TIME * 0.55));
	float edge = smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x) * smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.92, uv.y);
	float mist = clamp(slow * 0.9 + fast * 0.6 - 0.45, 0.0, 1.0);
	ALBEDO = tint.rgb * (0.7 + fast * 0.8);
	ALPHA = mist * edge * strength;
}
"""

@export var height := 8.0
@export var width := 2.6

var _material: ShaderMaterial
var _shape: CollisionShape3D
var _wisps: CPUParticles3D
var _light: OmniLight3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, height, 4.4)
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position.y = height * 0.5
	_shape.disabled = true
	add_child(_shape)
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	for i in 2:
		var quad := QuadMesh.new()
		quad.size = Vector2(width * (1.0 - 0.25 * i), height)
		var curtain := MeshInstance3D.new()
		curtain.mesh = quad
		curtain.material_override = _material
		curtain.position = Vector3(0.15 * i, height * 0.5, -0.9 * i)
		add_child(curtain)
	_wisps = CPUParticles3D.new()
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff_material.albedo_color = Color(0.6, 0.55, 0.9, 0.18)
	puff.material = puff_material
	_wisps.mesh = puff
	_wisps.amount = 26
	_wisps.lifetime = 3.0
	_wisps.emitting = false
	_wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_wisps.emission_box_extents = Vector3(width * 0.3, 0.2, 0.8)
	_wisps.direction = Vector3.UP
	_wisps.spread = 15.0
	_wisps.gravity = Vector3(0.0, 0.9, 0.0)
	_wisps.initial_velocity_min = 0.6
	_wisps.initial_velocity_max = 1.4
	_wisps.scale_amount_min = 1.0
	_wisps.scale_amount_max = 3.0
	add_child(_wisps)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.55, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 7.0
	_light.position = Vector3(0.0, 2.0, 1.0)
	add_child(_light)


func is_up() -> bool:
	return not _shape.disabled


func rise() -> void:
	_shape.disabled = false
	_wisps.emitting = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_material, "shader_parameter/strength", 1.0, RISE_TIME)
	tween.tween_property(_light, "light_energy", 1.4, RISE_TIME)


## Вспышка (переход фазы босса): стена на миг густеет.
func flare() -> void:
	var tween := create_tween()
	tween.tween_property(_material, "shader_parameter/strength", 2.2, 0.15)
	tween.tween_property(_material, "shader_parameter/strength", 1.0, 0.8)


func dissolve() -> void:
	_shape.set_deferred("disabled", true)
	_wisps.emitting = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_material, "shader_parameter/strength", 0.0, FADE_TIME)
	tween.tween_property(_light, "light_energy", 0.0, FADE_TIME)
