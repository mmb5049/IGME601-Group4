shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

// --- Uniforms ---
uniform vec4 circle_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 3.0;
uniform float ring_1_radius : hint_range(0.0, 1.0) = 0.45;
uniform float ring_1_width : hint_range(0.0, 0.1) = 0.01;
uniform float ring_2_radius : hint_range(0.0, 1.0) = 0.40;
uniform float ring_2_width : hint_range(0.0, 0.1) = 0.005;
uniform int dash_count = 16;
uniform float dash_speed = 1.0;
uniform float dash_radius : hint_range(0.0, 1.0) = 0.33;
uniform float dash_width : hint_range(0.0, 0.1) = 0.02;

// --- Helper Functions ---
float draw_ring(vec2 uv, float radius, float width) {
    float dist = length(uv - vec2(0.5));
    return smoothstep(width, 0.0, abs(dist - radius));
}

void fragment() {
    // Center UV coordinates to (-0.5, 0.5)
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv);
    
    // Base mask accumulator
    float mask = 0.0;
    
    // 1. Outer Solid Rings
    mask += draw_ring(UV, ring_1_radius, ring_1_width);
    mask += draw_ring(UV, ring_2_radius, ring_2_width);
    
    // 2. Rotating Segmented Dashes (Rune Stand-in)
    float angle = atan(centered_uv.y, centered_uv.x);
    // Rotate angle over time
    angle += TIME * dash_speed;
    // Segment the circle into steps
    float segments = sin(angle * float(dash_count));
    float dash_mask = draw_ring(UV, dash_radius, dash_width);
    // Sharp cutoff for the segments
    float segment_cutoff = smoothstep(0.0, 0.1, segments);
    mask += dash_mask * segment_cutoff;
    
    // 3. Central Pulsing Core
    float pulse = 0.15 + 0.03 * sin(TIME * 4.0);
    float core = smoothstep(pulse, pulse - 0.02, dist);
    // Hollow out the core slightly for a cooler effect
    float core_hollow = smoothstep(0.05, 0.07, dist);
    mask += core * core_hollow;

    // --- Output Assignments ---
    // Apply color and use the procedural mask for transparency
    ALBEDO = circle_color.rgb;
    ALPHA = clamp(mask, 0.0, 1.0) * circle_color.a;
    
    // Emission for Glow/Bloom effect
    EMISSION = circle_color.rgb * emission_strength * mask;
}
