uniform vec4 fill_color : source_color;
uniform vec4 damage_color : source_color;
uniform float spread;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Each edge expands along its own radius in the plane of the tile.
	vec2 radial = vec2(sin(UV.x), cos(UV.x));
	VERTEX.xz += radial * UV.y * spread * (1.0 - pow(1.0 - progress, 2.0));
}

void fragment() {
	ALBEDO = mix(fill_color.rgb, damage_color.rgb, smoothstep(0.0, 0.45, progress));
	ALPHA = 1.0 - smoothstep(0.15, 1.0, progress);
}
