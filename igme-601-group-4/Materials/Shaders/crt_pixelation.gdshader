shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 12.0, 1.0) = 2.0;
uniform float chromatic_aberration_pixels : hint_range(0.0, 8.0, 0.25) = 1.0;

void fragment() {
	vec2 sample_uv = SCREEN_UV;
	if (pixel_size > 1.0) {
		vec2 block_size = SCREEN_PIXEL_SIZE * pixel_size;
		sample_uv = (floor(sample_uv / block_size) + 0.5) * block_size;
	}
	vec4 scene_color = texture(screen_texture, sample_uv);
	if (chromatic_aberration_pixels > 0.0) {
		vec2 offset = vec2(SCREEN_PIXEL_SIZE.x * chromatic_aberration_pixels, 0.0);
		scene_color.r = texture(screen_texture, sample_uv + offset).r;
		scene_color.b = texture(screen_texture, sample_uv - offset).b;
	}
	COLOR = scene_color;
}
