shader_type spatial;

uniform vec3 color:source_color = vec3(1,1,1);
uniform sampler2D cracked_texture;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec3 cracked_mult = texture(cracked_texture,UV).xyz;
	ALBEDO = color * cracked_mult; 
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
