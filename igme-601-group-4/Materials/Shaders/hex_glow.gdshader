shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.3, 1.0);

uniform float glow_strength = 4.0;
uniform float glow_speed = 3.0;
uniform float edge_thickness = 0.2;

varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// Normalize so the hex circumradius is 1.0
	vec2 p = local_position.xz / 0.95;

	vec2 normals[6];
	normals[0] = vec2(1.0, 0.0);
	normals[1] = vec2(0.5, 0.8660254);
	normals[2] = vec2(-0.5, 0.8660254);
	normals[3] = vec2(-1.0, 0.0);
	normals[4] = vec2(-0.5, -0.8660254);
	normals[5] = vec2(0.5, -0.8660254);

	// Distance to the nearest edge. Edges sit at the apothem (0.866), not 1.0
	float edge_distance = 1.0;
	for (int i = 0; i < 6; i++) {
		edge_distance = min(edge_distance, 0.8660254 - dot(p, normals[i]));
	}

	// Top face only, detected by normal
	float top_mask = step(0.9, local_normal.y);

	float edge_mask = 1.0 - smoothstep(0.0, edge_thickness, edge_distance);

	float pulse = 0.5 + 0.5 * sin(TIME * glow_speed);
	float glow = edge_mask * top_mask * (0.5 + pulse);

	ALBEDO = base_color.rgb;
	EMISSION = glow_color.rgb * glow * glow_strength;
	ROUGHNESS = 0.5;
}