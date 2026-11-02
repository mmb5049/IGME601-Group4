
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// ==========================================
// COLOR CUSTOMIZATION
// ==========================================

uniform vec4 outer_ring_color : source_color = vec4(0.2, 0.7, 1.0, 1.0);
uniform vec4 second_ring_color : source_color = vec4(0.5, 0.3, 1.0, 1.0);
uniform vec4 inner_ring_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform vec4 dash_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);

// ==========================================
// OUTER RING
// ==========================================

uniform float outer_radius : hint_range(0.0, 1.0) = 0.45;
uniform float outer_width : hint_range(0.0, 0.1) = 0.012;
uniform float outer_emission : hint_range(0.0, 20.0) = 5.0;
uniform float outer_glow_width : hint_range(0.0, 0.1) = 0.04;
uniform float outer_glow_strength : hint_range(0.0, 5.0) = 1.5;

// ==========================================
// SECOND RING (SEGMENTED)
// ==========================================

uniform float second_radius : hint_range(0.0, 1.0) = 0.40;
uniform float second_width : hint_range(0.0, 0.1) = 0.006;
uniform int second_gap_count = 12;
uniform float second_gap_size : hint_range(0.0, 0.5) = 0.08;
uniform float second_rotation_speed = 0.0;
uniform float second_emission : hint_range(0.0, 20.0) = 3.0;

// ==========================================
// INNER RING (SOLID)
// ==========================================

uniform float inner_radius : hint_range(0.0, 1.0) = 0.29;
uniform float inner_width : hint_range(0.0, 0.1) = 0.012;
uniform float inner_emission : hint_range(0.0, 20.0) = 3.0;

// ==========================================
// ROTATING DASHES
// ==========================================

uniform int dash_count = 16;
uniform float dash_speed = 1.0;
uniform float dash_radius : hint_range(0.0, 1.0) = 0.33;
uniform float dash_width : hint_range(0.0, 0.1) = 0.02;
uniform float dash_emission : hint_range(0.0, 20.0) = 3.0;


// ==========================================
// HELPER FUNCTIONS
// ==========================================

float draw_ring(vec2 uv, float radius, float width) {
    float dist = length(uv - vec2(0.5));
    return 1.0 - smoothstep(width * 0.5, width * 0.5 + 0.003, abs(dist - radius));
}

void fragment() {
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv);

    float total_alpha = 0.0;
    vec3 total_emission = vec3(0.0);

    // ======================================
    // 1. OUTER NEON RING
    // ======================================

    float outer_dist = abs(dist - outer_radius);

    float outer_ring = draw_ring(UV, outer_radius, outer_width);

    // Soft glow surrounding the outer ring
    float outer_glow = exp(
        -pow(outer_dist / max(outer_glow_width, 0.001), 2.0)
    );

    total_alpha += outer_ring * outer_ring_color.a;
    
    total_emission += outer_ring_color.rgb *
        (outer_ring * outer_emission +
        outer_glow * outer_glow_strength);

    // ======================================
    // 2. SECOND RING WITH SMALL GAPS
    // ======================================

    float angle = atan(centered_uv.y, centered_uv.x);
    float second_angle = angle + TIME * second_rotation_speed;

    float second_ring = draw_ring(UV, second_radius, second_width);

    // Repeating angular pattern
    float gap_pattern = abs(
        fract(second_angle * float(second_gap_count) / 6.2831853) - 0.5
    );

    float gap_mask = smoothstep(
        second_gap_size,
        second_gap_size + 0.04,
        gap_pattern
    );

    second_ring *= gap_mask;

    total_alpha += second_ring * second_ring_color.a;
    total_emission += second_ring_color.rgb *
        second_ring * second_emission;

    // ======================================
    // 3. INNER SOLID RING
    // ======================================

    float inner_ring = draw_ring(UV, inner_radius, inner_width);

    total_alpha += inner_ring * inner_ring_color.a;
    total_emission += inner_ring_color.rgb *
        inner_ring * inner_emission;

    // ======================================
    // 4. ROTATING SEGMENTED DASHES
    // ======================================

    float dash_angle = angle + TIME * dash_speed;

    float segments = sin(dash_angle * float(dash_count));

    float dash_ring = draw_ring(UV, dash_radius, dash_width);

    float dash_mask = smoothstep(0.0, 0.1, segments);

    float dashes = dash_ring * dash_mask;

    total_alpha += dashes * dash_color.a;
    total_emission += dash_color.rgb *
        dashes * dash_emission;

    
    // ======================================
    // OUTPUT
    // ======================================

ALBEDO = (
    outer_ring_color.rgb * outer_ring +
    second_ring_color.rgb * second_ring +
    inner_ring_color.rgb * inner_ring +
    dash_color.rgb * dashes
);

EMISSION = total_emission;

ALPHA = clamp(total_alpha, 0.0, 1.0);
}
