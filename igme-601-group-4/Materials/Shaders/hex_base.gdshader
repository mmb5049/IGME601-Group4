shader_type spatial;

uniform vec4 color:source_color = vec4(0.202,0.202,0.202,1);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = color.rgb;
	ROUGHNESS = 0.5;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
