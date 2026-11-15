// Процедурное пламя (Flame): язык огня на кваде без текстур. Тело мягкое: широкое у основания, тянется
// кверху тонким рваным языком, края колышутся сильнее к вершине и не режутся в треугольник. Шум бежит
// вверх, цвет — от золотистого ядра к тёмно-красным кончикам (белого пятна нет: оно плоско смотрится
// рядом с рисованными моделями). Квад всегда стоит вертикально и поворачивается к камере вокруг оси Y.
// Работает и на частицах (COLOR — их цвет и прозрачность).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.4, 0.07, 1.0);
uniform vec4 tip_color : source_color = vec4(0.5, 0.06, 0.015, 1.0);
uniform float intensity = 0.95;
uniform float speed = 1.3;
// Своё у каждого языка: сдвиг шума и общая яркость (угасание).
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
// Размер квада в метрах: нужен, чтобы срез основания шёл по поверхности, а не по краю квада.
instance uniform vec2 dim = vec2(1.0, 1.0);
// Поверхность под огнём в метрах от низа квада: (сдвиг конька по x от центра квада, высота конька над
// низом, наклон dy/dx). Горит ровно — (0, 0, 0): плоский низ; на скате крыши — «шатёр» с ребром на коньке,
// основание огня ложится по скату, а сам огонь всё равно растёт вертикально вверх.
instance uniform vec3 surface = vec3(0.0, 0.0, 0.0);

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
	float side = (UV.x - 0.5) * 2.0;
	// Ось языка гнётся по высоте плавной S-кривой: огонь вьётся, а не торчит конусом.
	float axis = (fbm(vec2(seed * 3.1, h * 1.1 - t * 0.45)) - 0.5) * 1.1 * h + sin(h * 5.0 - t * 2.0 + seed * 6.0) * 0.07 * h;
	float px = side - axis;
	// Капля: у основания полная, кверху сужается до округлого кончика.
	float width = max(0.85 * pow(1.0 - h, 0.75) * (0.78 + 0.22 * smoothstep(0.0, 0.2, h)), 0.06);
	// Край дышит низкочастотным шумом: чем выше, тем сильнее — кончик распадается на пряди, но без зубьев.
	float edge = (fbm(vec2(px * 1.3 + seed, h * 2.1 - t * 1.6)) - 0.5) * 0.6 * (0.25 + h);
	float body = 1.0 - smoothstep(0.3, 1.0, abs(px) / width + edge);
	body *= 1.0 - smoothstep(0.8, 1.0, h);
	float ripple = fbm(vec2(px * 2.0 - seed, h * 3.0 - t * 2.2)) - 0.5;
	float heat = clamp(body * (1.0 - 0.4 * h + ripple * 0.5), 0.0, 1.0);
	vec3 col = mix(tip_color.rgb, flame_color.rgb, smoothstep(0.05, 0.5, heat));
	col = mix(col, core_color.rgb, smoothstep(0.62, 0.95, heat) * 0.85);
	// Основание обрезано по поверхности под огнём с коротким мягким краем.
	float surf = surface.y - surface.z * abs((UV.x - 0.5) * dim.x - surface.x);
	float cut = smoothstep(0.0, min(0.1, dim.y * 0.25), h * dim.y - surf);
	// Огонь не упирается в боковые края квада: язык, ушедший в сторону, тает, а не режется по вертикали.
	float sides = 1.0 - smoothstep(0.72, 1.0, abs(side));
	ALBEDO = col * intensity * COLOR.rgb;
	ALPHA = smoothstep(0.02, 0.5, heat) * cut * sides * fade * COLOR.a;
}
