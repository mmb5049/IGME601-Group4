shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Simple horizontal glitch displacement
    float slice = step(0.95, random(vec2(TIME * 0.5, floor(uv.y * 20.0))));
    uv.x += slice * (random(vec2(TIME)) - 0.5) * glitch_intensity;
    
    // Sample the screen with RGB channel splitting
    float r = texture(SCREEN_TEXTURE, uv + vec2(0.005, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - vec2(0.005, 0.0)).b;
    
    // Scanlines
    float scanline = sin(uv.y * 800.0) * scanline_intensity;
    vec3 color = vec3(r, g, b) - scanline;
    
    COLOR = vec4(color, 1.0);
}
