// Лава Пекла (§8.13): тёмная корка с горячими трещинами, корка медленно течёт, свечение дышит.
// Без освещения сцены: лава — единственное яркое в кадре (палитра Пекла, STYLE_BIBLE §4).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 hot : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 crust : source_color = vec3(0.07, 0.02, 0.012);
uniform float flow = 0.05;

varying vec3 world_pos;

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
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.55 + vec2(TIME * flow, TIME * flow * 0.35);
	float n = fbm(p + fbm(p * 0.7 - TIME * 0.02));
	float cracks = smoothstep(0.42, 0.6, n);
	float breathe = 0.85 + 0.15 * sin(TIME * 1.1 + world_pos.x * 0.6);
	ALBEDO = mix(crust, hot * breathe, cracks) + hot * 0.12;
}
