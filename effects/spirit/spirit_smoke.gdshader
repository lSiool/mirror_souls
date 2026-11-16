// Дым проклятого духа (Безмолвный Кузнец, 2026-11-17): рваные струйки из шума ползут вверх и «разъедаются»
// к концу жизни — не размытые круги. Возраст частицы — INSTANCE_CUSTOM.y (0…1), свой рисунок — по углу
// поворота INSTANCE_CUSTOM.x; COLOR.a — общая прозрачность по возрасту (color_ramp).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 dark_color : source_color = vec4(0.16, 0.1, 0.3, 1.0);
uniform vec4 light_color : source_color = vec4(0.48, 0.36, 0.78, 1.0);
uniform float density = 0.75;
uniform float rise_speed = 0.7;

varying float rnd;
varying float age;

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
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	rnd = fract(INSTANCE_CUSTOM.x * 0.1591 + 0.37);
	age = INSTANCE_CUSTOM.y;
	// Билборд, повёрнутый только вокруг вертикали: струйки остаются вертикальными.
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
	vec2 q = p * vec2(1.1, 0.8) + vec2(rnd * 19.0, TIME * rise_speed);
	// Закрутка: шум сдвигает сам себя — получаются языки, а не пятна.
	vec2 warp = vec2(fbm(q * 1.3), fbm(q * 1.3 + 5.2));
	float n = fbm(q * 1.5 + warp * 1.4);
	float shape = 1.0 - smoothstep(0.25, 1.0, length(p * vec2(1.4, 0.85)));
	// Разъедание к концу жизни: порог растёт с возрастом.
	float cut = mix(0.26, 0.66, age);
	float wisp = smoothstep(cut, cut + 0.3, n) * shape;
	ALBEDO = mix(dark_color.rgb, light_color.rgb, smoothstep(0.4, 0.85, n));
	ALPHA = wisp * density * COLOR.a;
}
