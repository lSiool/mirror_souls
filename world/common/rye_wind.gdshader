// Рожь на ветру (§8.13, Поля): колос клонится тем сильнее, чем выше точка; по полю бегут волны и порывы.
// Цвет колоса — цвет экземпляра MultiMesh, к земле темнее.
shader_type spatial;
render_mode cull_disabled;

uniform float sway = 0.09;
uniform float gust = 0.22;
// Кто идёт под колосьями (Полудница, §8.14 «волна во ржи»): x и z мира, сила 0…1, полуширина полосы по x.
// Там колосья клонятся против ветра и мелко дрожат — бегущая полоса выдаёт её.
uniform vec4 disturb = vec4(0.0, 0.0, 0.0, 1.5);

varying float tip;

void vertex() {
	tip = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wave = sin(world.x * 0.45 - TIME * 1.7 + world.z * 0.8) * 0.5 + 0.5;
	float roll = smoothstep(0.2, 1.0, sin(world.x * 0.07 - TIME * 0.45) * 0.5 + 0.5);
	VERTEX.x += tip * tip * (sway + gust * wave * roll);
	VERTEX.z += tip * tip * 0.04 * sin(TIME * 2.3 + world.x * 1.7);
	float near = disturb.z * (1.0 - smoothstep(0.0, disturb.w, abs(world.x - disturb.x)));
	VERTEX.x -= tip * tip * near * 0.6;
	VERTEX.x += tip * tip * near * 0.14 * sin(TIME * 27.0 + world.z * 9.0 + world.x * 5.0);
	VERTEX.y -= tip * near * 0.1;
}

void fragment() {
	ALBEDO = COLOR.rgb * mix(0.35, 1.0, tip);
	ROUGHNESS = 0.95;
}
