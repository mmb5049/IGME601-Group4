shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled;
// Fill the silhouette outside the visible mask and mark those pixels for the outline.
stencil_mode read, write, compare_not_equal, 7;

uniform vec4 tint : source_color = vec4(1.0, 0.27, 0.34, 0.53);

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = tint.rgb * mix(0.75, 1.15, facing);
	ALPHA = tint.a;
}
