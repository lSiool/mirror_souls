// Мягкое свечение (FireSpot): круглое пятно без текстур, затухает от центра к краю. Подкладывается под
// языки пламени, чтобы огонь не казался наклейкой, и рисует искры — те же пятна поменьше и поярче.
// Квад всегда стоит вертикально и поворачивается к камере; COLOR — цвет и прозрачность частицы.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.42, 0.1, 1.0);
uniform float strength = 0.5;
// Больше — гуще в центре и мягче к краю.
uniform float softness = 2.2;
// Биение: своё у каждого пятна.
instance uniform float seed = 0.0;

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
	float d = clamp(1.0 - length((UV - 0.5) * 2.0), 0.0, 1.0);
	float pulse = 0.82 + 0.18 * sin(TIME * 6.5 + seed * 11.0) * sin(TIME * 2.3 + seed * 5.0);
	ALBEDO = glow_color.rgb * COLOR.rgb;
	ALPHA = pow(d, softness) * strength * pulse * COLOR.a;
}
