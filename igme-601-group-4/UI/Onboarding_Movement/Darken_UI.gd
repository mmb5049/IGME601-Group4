extends ColorRect

func ChangeSize ():
	material.set_shader_parameter("cutout_position", Vector2(100, 100))
	material.set_shader_parameter("cutout_size", Vector2(100, 100))
