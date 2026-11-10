// Процедурное пламя (Flame): язык огня на кваде без текстур. Шум бежит вверх, края колышутся
// сильнее к вершине, цвет — от белого ядра к красным кончикам. Квад всегда стоит вертикально
// и поворачивается к камере вокруг оси Y. Работает и на частицах (COLOR — их цвет и прозрачность).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.62, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(0.6, 0.07, 0.02, 1.0);
uniform float intensity = 1.15;
uniform float speed = 1.5;
// Своё у каждого языка: сдвиг шума и общая яркость (угасание).
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;

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
	float h = 1.0 - UV.y;
	float t = TIME * speed + seed * 17.3;
	float sway = fbm(vec2(UV.x * 2.0 + seed, h * 1.6 - t * 0.8));
	float detail = fbm(vec2(UV.x * 5.5 - seed, h * 3.8 - t * 1.9));
	float x = (UV.x - 0.5) * 2.0 + (sway - 0.5) * 0.9 * h;
	// Полное тело внизу, язык сужается к вершине. Ширина не доходит до нуля: smoothstep с равными
	// краями не определён, и на видеокарте вершина квада светилась мигающей полосой.
	float width = max(mix(0.95, 0.0, pow(h, 1.3)), 0.02);
	float body = 1.0 - smoothstep(width * 0.45, width, abs(x));
	body *= smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.9, 1.0, h));
	float heat = clamp((body * (detail * 0.7 + 0.55) - h * 0.45) * 1.45, 0.0, 1.0);
	vec3 col = mix(tip_color.rgb, flame_color.rgb, smoothstep(0.05, 0.45, heat));
	col = mix(col, core_color.rgb, smoothstep(0.75, 1.0, heat));
	ALBEDO = col * intensity * COLOR.rgb;
	ALPHA = smoothstep(0.03, 0.3, heat) * fade * COLOR.a;
}
