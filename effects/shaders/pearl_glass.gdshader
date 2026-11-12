// Перламутровое стекло нестабильного отражения (§8.11): цвет переливается по углу взгляда и
// по месту в мире, края светятся. crack — трещины перед тем, как глыба рассыплется.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform float alpha = 0.62;
uniform float seed = 0.0;
uniform float crack = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float band = sin(world.x * 0.35 + world.y * 0.8 + seed * 6.0 + TIME * 0.3 + rim * 3.0);
	vec3 pearl = 0.6 + 0.4 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + band * 0.18 + rim * 0.5 + seed));
	// Трещины: ломаная сетка, проступает с ростом crack.
	vec2 cell = floor(world.xy * 3.0 + seed * 10.0);
	float lines = step(0.86, hash(cell)) + step(0.93, hash(cell + 7.0));
	float broken = clamp(lines, 0.0, 1.0) * crack;
	// Бледное холодное стекло; перламутр — тонкая плёнка, сильнее всего по краям.
	ALBEDO = mix(vec3(0.62, 0.7, 0.82), pearl, 0.12 + rim * 0.35);
	EMISSION = pearl * rim * 0.55 + vec3(0.25, 0.32, 0.45) * 0.25 + vec3(1.0) * (broken * 2.5 + crack * 0.4);
	ROUGHNESS = 0.08;
	METALLIC = 0.3;
	ALPHA = clamp(mix(alpha, 0.96, rim) + broken, 0.0, 1.0);
}
