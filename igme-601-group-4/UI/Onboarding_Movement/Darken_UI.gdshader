shader_type canvas_item;

// Positions and sizes are passed in raw screen pixels
uniform vec2 cutout_position; 
uniform vec2 cutout_size;

void fragment() {
	// SCREEN_UV * viewport_size gives the actual pixel coordinate
	vec2 pixel_pos = SCREEN_UV / SCREEN_PIXEL_SIZE; 
	vec2 half_size = cutout_size * 0.5;
	
	// Check if the current pixel is inside the box bounds
	if (pixel_pos.x >= (cutout_position.x - half_size.x) &&
	    pixel_pos.x <= (cutout_position.x + half_size.x) &&
	    pixel_pos.y >= (cutout_position.y - half_size.y) &&
	    pixel_pos.y <= (cutout_position.y + half_size.y)) {
		discard; // Make transparent
	}
}