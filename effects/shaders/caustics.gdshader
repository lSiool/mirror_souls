// Стеклянная каустика на фоне нестабильного отражения (§8.11): сетка бликов, как свет сквозь
// битое стекло, медленно плывёт и переливается перламутром. Плоскость без освещения.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float scale = 5.0;
uniform float speed = 0.35;
uniform float glow = 1.0;
uniform vec4 deep : source_color = vec4(0.02, 0.02, 0.07, 1.0);

float caustic(vec2 uv, float t) {
	vec2 p = mod(uv * 6.28318, 6.28318) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 5; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 5.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

void fragment() {
	vec2 uv = UV * vec2(scale * 4.0, scale);
	float t = TIME * speed;
	float a = caustic(uv, t);
	float b = caustic(uv * 0.53 + 3.7, t * 0.7 + 4.0);
	// Холодные блики с лёгким перламутровым отливом — свет сквозь битое стекло, а не радуга.
	vec3 pearl = mix(vec3(0.55, 0.68, 0.95), 0.6 + 0.4 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + uv.x * 0.04 + t * 0.1)), 0.25);
	float edge = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	ALBEDO = deep.rgb + (pearl * a * 0.32 + vec3(0.5, 0.6, 0.9) * b * 0.12) * glow * edge;
}
