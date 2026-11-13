shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
stencil_mode write, compare_always, 7;

void vertex() {
	// Bias toward the camera so the mask also covers the opaque model at equal depth.
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_position.z += 0.025;
	POSITION = PROJECTION_MATRIX * view_position;
}

void fragment() {
	ALPHA = 0.0;
}
