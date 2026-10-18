shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// Стекло с френелем и бегущей полосой блика (§3.3, §5.1).
// Блик тянется за героем и усиливается рядом с ним. Тип стекла меняет характер блика:
// чистое — ровная белая полоса, мутное — блик рвётся и внутри шевелится тень,
// с красными прожилками — блик на миг вспыхивает красным.

uniform vec4 base_color : source_color = vec4(0.62, 0.78, 0.88, 0.3);
uniform vec4 gleam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gleam_width = 0.35;
uniform float gleam_speed = 0.7;
uniform float gleam_strength = 1.4;
uniform float fresnel_power = 3.0;
uniform float tear = 0.0;
uniform float shadow = 0.0;
uniform float red_pulse = 0.0;
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform float proximity_radius = 4.0;

varying vec3 world_pos;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float closeness = 1.0 - smoothstep(0.0, proximity_radius, distance(world_pos.xy, player_pos.xy));

	// Диагональная полоса блика, привязанная к позиции героя.
	float coord = world_pos.x + world_pos.y * 0.6;
	float center = player_pos.x + player_pos.y * 0.6 + sin(TIME * gleam_speed) * 1.2;
	float band = 1.0 - smoothstep(0.0, gleam_width, abs(coord - center));

	// Мутное: блик рвётся на куски.
	float torn = step(tear * 0.75, hash(floor(world_pos.y * 7.0) * 13.0 + floor(TIME * 9.0)));
	band *= mix(1.0, torn, step(0.001, tear));
	float intensity = band * (0.3 + 0.7 * closeness) * gleam_strength;

	// Прожилки: короткая красная вспышка раз в пару секунд.
	float pulse = red_pulse * step(0.86, fract(TIME * 0.45 + world_pos.x * 0.05));
	vec3 gleam = mix(gleam_color.rgb, vec3(1.0, 0.08, 0.04), pulse);
	vec2 vein_uv = world_pos.xy * vec2(2.3, 3.1);
	float vein = red_pulse * (1.0 - smoothstep(0.0, 0.06, abs(sin(vein_uv.x + sin(vein_uv.y * 1.7) * 1.3))));

	// Мутное: тень, которая медленно шевелится внутри.
	vec2 blob_uv = fract(world_pos.xy * 0.4 + vec2(TIME * 0.12, sin(TIME * 0.8) * 0.15));
	float blob = shadow * (1.0 - smoothstep(0.15, 0.45, distance(blob_uv, vec2(0.5))));

	ALBEDO = base_color.rgb * (1.0 - blob * 0.85);
	EMISSION = gleam * intensity
		+ base_color.rgb * fres * 0.6
		+ vec3(0.9, 0.05, 0.03) * (vein * 0.5 + pulse * 0.35);
	ROUGHNESS = 0.05;
	METALLIC = 0.2;
	SPECULAR = 0.9;
	ALPHA = clamp(base_color.a + fres * 0.35 + intensity * 0.5 + blob * 0.6 + vein * 0.5, 0.0, 1.0);
}
