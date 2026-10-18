shader_type canvas_item;

void fragment() {
	vec4 icon_color = texture(TEXTURE, UV) * COLOR;

	// Calculate a point-up hexagon directly from the TextureRect UVs.
	// Keeping the mask procedural prevents a missing texture parameter from
	// silently turning the Ability icon back into a rectangle.
	vec2 centered_uv = abs(UV - vec2(0.5));
	float hex_distance = max(
		centered_uv.x / 0.8660254,
		centered_uv.x * 0.5773503 + centered_uv.y
	);
	float mask_alpha = 1.0 - smoothstep(0.49, 0.5, hex_distance);

	icon_color.a *= mask_alpha;
	COLOR = icon_color;
}
