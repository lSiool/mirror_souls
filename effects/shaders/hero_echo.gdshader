shader_type spatial;
// Отзвук героя: светящийся силуэт без лица. Контур светится сильнее середины, по телу
// бегут прорехи, горизонтальные полосы изредка сдвигаются — фигура то и дело распадается.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.45, 0.72, 1.0, 1.0);
// 1 — виден, 0 — растворился (герой забрал отзвук).
uniform float strength : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float band = step(0.9, noise(vec2(floor(world_pos.y * 9.0), floor(TIME * 7.0))));
	VERTEX.x += band * (noise(vec2(world_pos.y * 20.0, TIME * 13.0)) - 0.5) * 0.3;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float flicker = 0.7 + 0.3 * noise(vec2(TIME * 3.0, world_pos.y * 2.0));
	float holes = smoothstep(0.22, 0.6, noise(world_pos.xy * 6.0 + vec2(0.0, TIME * 0.8)));
	// Растворение: с уходом strength фигура рассыпается пятнами.
	float dissolve = smoothstep(0.0, 0.25, strength * 1.3 - noise(world_pos.xy * 9.0));
	ALBEDO = tint.rgb * (0.12 + rim * 0.9) * flicker * holes * dissolve * strength * 1.8;
}
