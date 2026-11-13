shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_strength : hint_range(0.0, 0.3, 0.01) = 0.08;
uniform float scanline_spacing_pixels : hint_range(2.0, 24.0, 1.0) = 3.0;
uniform float scanline_width_pixels : hint_range(1.0, 12.0, 1.0) = 1.0;
uniform float scanline_softness_pixels : hint_range(0.0, 2.0, 0.1) = 0.0;
uniform float vignette_strength : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float brightness : hint_range(0.8, 1.2, 0.01) = 1.02;
uniform float curvature_strength : hint_range(0.0, 0.20, 0.005) = 0.025;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	// Keep this display-to-source transform in sync with crt_overlay.gd.
	vec2 curved = centered * (1.0 + curvature_strength * centered.yx * centered.yx);
	vec2 sample_uv = curved * 0.5 + 0.5;
	vec3 scene_color = texture(screen_texture, sample_uv).rgb;
	// Center the dark band at the end of each period, leaving at least one
	// bright pixel between bands before edge softening is applied.
	float spacing = scanline_spacing_pixels;
	float half_width = min(scanline_width_pixels, spacing - 1.0) * 0.5;
	float phase = mod(FRAGCOORD.y + half_width + spacing * 0.5, spacing);
	float distance_to_line = abs(phase - spacing * 0.5);
	float line_mask = 1.0 - step(half_width, distance_to_line);
	if (scanline_softness_pixels > 0.0) {
		float softness = scanline_softness_pixels;
		line_mask = 1.0 - smoothstep(half_width - softness, half_width + softness, distance_to_line);
	}
	float scanline = 1.0 - scanline_strength * line_mask;
	float corner_distance = dot(centered, centered) * 0.5;
	float vignette = 1.0 - vignette_strength * smoothstep(0.15, 1.0, corner_distance);
	float screen_mask = 1.0 - step(1.0, max(abs(curved.x), abs(curved.y)));
	COLOR = vec4(scene_color * brightness * scanline * vignette * screen_mask, 1.0);
}
