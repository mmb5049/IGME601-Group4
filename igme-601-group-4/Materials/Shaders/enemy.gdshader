shader_type spatial;

uniform vec3 base_color = vec3(1,0,0);
uniform vec3 flash_color = vec3(1,1,1);
instance uniform bool is_flashing = false;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	if (is_flashing){
		ALBEDO = flash_color;
		ROUGHNESS = 1.0;
		EMISSION = flash_color;
	}
	else{
		ALBEDO = base_color;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
