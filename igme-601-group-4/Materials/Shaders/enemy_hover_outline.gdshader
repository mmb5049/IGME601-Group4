shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled;
stencil_mode read, write, compare_not_equal, 7;

uniform vec4 glow_color : source_color = vec4(1.0, 0.30, 0.38, 0.9);
uniform float width_pixels = 3.0;
uniform float glow_strength = 2.4;
uniform float glow_speed = 3.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = MODELVIEW_NORMAL_MATRIX * NORMAL;
	vec2 projected_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	vec2 screen_normal = projected_normal * VIEWPORT_SIZE;
	vec2 direction = screen_normal / max(length(screen_normal), 0.0001);
	clip.xy += direction * (2.0 * width_pixels / VIEWPORT_SIZE) * clip.w;
	POSITION = clip;
}

void fragment() {
	float pulse = 0.85 + 0.15 * sin(TIME * glow_speed);
	ALBEDO = glow_color.rgb * glow_strength * pulse;
	ALPHA = glow_color.a;
}
