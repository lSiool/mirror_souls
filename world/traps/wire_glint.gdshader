shader_type spatial;
// Нить растяжки (§8.14): почти не видна, но вспыхивает тонким бликом, когда камера проходит нужный угол.
// Блик анизотропный, как у натянутой нитки (Kajiya-Kay): ярко, когда угол «нить — свет» и угол «нить — взгляд»
// в сумме дают прямой; свет условный, сверху сбоку, чтобы блеск не зависел от ламп в комнате.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 base_color : source_color = vec4(0.07, 0.065, 0.06, 1.0);
uniform vec3 glint_color : source_color = vec3(1.0, 0.94, 0.82);
uniform vec3 light_dir = vec3(-0.55, 0.75, 0.35);
// Чем больше, тем короче вспышка при движении камеры.
uniform float sharpness = 160.0;
uniform float strength = 2.4;

varying vec3 axis_world;

void vertex() {
	// Ось цилиндра — его локальный Y.
	axis_world = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 t = axis_world;
	vec3 l = normalize(light_dir);
	float tl = dot(t, l);
	float tv = dot(t, v);
	float spec = sqrt(max(0.0, 1.0 - tl * tl)) * sqrt(max(0.0, 1.0 - tv * tv)) - tl * tv;
	float glint = pow(max(spec, 0.0), sharpness) * strength;
	// Без освещения итог — сам ALBEDO; блик выше единицы подхватывает свечение (glow) комнаты.
	ALBEDO = base_color.rgb + glint_color * glint;
}
