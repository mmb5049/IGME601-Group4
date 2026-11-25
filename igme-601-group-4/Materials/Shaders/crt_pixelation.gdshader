shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 12.0, 0.1) = 2.0;
uniform float chromatic_aberration_pixels : hint_range(0.0, 8.0, 0.25) = 1.0;
uniform bool isolated_content = false;

void fragment() {
	vec2 sample_uv = SCREEN_UV;
	if (pixel_size > 1.0) {
		vec2 block_size = SCREEN_PIXEL_SIZE * pixel_size;
		sample_uv = (floor(sample_uv / block_size) + 0.5) * block_size;
	}
	vec4 scene_color = texture(screen_texture, sample_uv);
	if (chromatic_aberration_pixels > 0.0) {
		vec2 offset = vec2(SCREEN_PIXEL_SIZE.x * chromatic_aberration_pixels, 0.0);
		vec4 red_sample = texture(screen_texture, sample_uv + offset);
		vec4 blue_sample = texture(screen_texture, sample_uv - offset);
		scene_color.r = red_sample.r;
		scene_color.b = blue_sample.b;
		if (isolated_content) {
			scene_color.a = max(scene_color.a, max(red_sample.a, blue_sample.a));
		}
	}
	if (isolated_content) {
		// CanvasGroup supplies premultiplied pixels from its children.
		scene_color.rgb /= max(scene_color.a, 0.0001);
		COLOR *= scene_color;
	} else {
		COLOR = scene_color;
	}
}
