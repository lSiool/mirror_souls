shader_type canvas_item;
// Блик стекла в HUD (§8.12): в тёмной комнате стекло тускнеет, на солнце по нему бежит блик.
// light 0…1 задаёт Hud по освещению комнаты.

uniform float light : hint_range(0.0, 1.0) = 0.5;
uniform float period = 3.6;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = fract(TIME / period);
	float pos = t * 2.4 - 0.7;
	float d = abs(UV.x * 0.85 + UV.y * 0.45 - pos);
	float glint = smoothstep(0.07, 0.0, d) * smoothstep(0.35, 1.0, light);
	COLOR = vec4(c.rgb * (0.55 + 0.45 * light) + vec3(glint * 0.85) * c.a, c.a);
}
