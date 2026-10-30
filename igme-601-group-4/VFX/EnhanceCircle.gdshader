shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D magic_circle_texture : source_color, filter_linear_mipmap;
uniform vec4 circle_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float rotation_speed : hint_range(-10.0, 10.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float glow_intensity : hint_range(1.0, 5.0) = 1.5;

void fragment() {
    // 1. Calculate rotation over time around the center (0.5, 0.5)
    vec2 uv = UV - 0.5;
    float angle = TIME * rotation_speed;
    float cos_a = cos(angle);
    float sin_a = sin(angle);
    vec2 rotated_uv = vec2(
        uv.x * cos_a - uv.y * sin_a,
        uv.x * sin_a + uv.y * cos_a
    ) + 0.5;

    // 2. Sample your custom rune/circle texture using the rotated UVs
    vec4 tex = texture(magic_circle_texture, rotated_uv);

    // 3. Create a pulsing glow effect
    float pulse = 1.0 + (sin(TIME * pulse_speed) * 0.15);

    // 4. Output final color and transparency
    ALBEDO = circle_color.rgb * tex.rgb * glow_intensity * pulse;
    ALPHA = tex.a * circle_color.a;
}