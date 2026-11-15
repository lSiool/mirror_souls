// Дым пожара (FireSpot): мягкий тёмный клуб с рваным краем, без текстур. Частицы растут и тают
// (COLOR.a — прозрачность по возрасту). У каждой частицы свой рисунок края — по углу поворота в INSTANCE_CUSTOM.x.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 smoke_color : source_color = vec4(0.045, 0.03, 0.026, 1.0);
uniform float density = 0.5;

varying float rnd;

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
	for (int i = 0; i < 3; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void vertex() {
	rnd = fract(INSTANCE_CUSTOM.x * 0.3183 + 0.5);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float n = fbm(p * 1.9 + vec2(rnd * 17.0, TIME * 0.12));
	float cloud = 1.0 - smoothstep(0.15, 1.0, length(p) + (n - 0.5) * 0.8);
	ALBEDO = smoke_color.rgb;
	ALPHA = cloud * density * COLOR.a;
}
