shader_type spatial;
render_mode unshaded;
stencil_mode read, compare_not_equal, 1;

// Positions and sizes are passed in raw screen pixels
uniform vec2 cutout_position; 
uniform vec2 cutout_size;

void vertex(){
	// Set the position to be in front of the camera no matter what
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	discard; // Make transparent
}