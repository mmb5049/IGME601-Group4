shader_type canvas_item;

void fragment() {
	// Use the green glow's intensity for red and retain its original alpha.
	COLOR.rgb = vec3(COLOR.g, COLOR.r * 0.25, COLOR.b);
}
