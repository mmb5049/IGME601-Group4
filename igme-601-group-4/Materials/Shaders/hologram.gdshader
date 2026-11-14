shader_type spatial;

uniform float emission_power = 20.0;
uniform vec3 emission_color:source_color = vec3(0,1,1);
uniform float alpha = 0.5;
uniform bool use_texture = false;
uniform sampler2D base_texture;
uniform vec3 texture_color:source_color = vec3(1,1,1);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float normal_power = clamp(0.5-dot(normalize(CAMERA_POSITION_WORLD-world_pos),world_normal),0.0,1.0);
	
	if (use_texture)
		ALBEDO = texture(base_texture,UV).rgb * texture_color;
	else
		ALBEDO = texture_color;
	ALPHA = alpha;
	EMISSION = emission_color * emission_power * normal_power;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
