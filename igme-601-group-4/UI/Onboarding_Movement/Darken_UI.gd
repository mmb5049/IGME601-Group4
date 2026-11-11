extends ColorRect


func ChangeSize (dimension, position):
	material.set_shader_parameter("cutout_position", position)
	material.set_shader_parameter("cutout_size", dimension)
