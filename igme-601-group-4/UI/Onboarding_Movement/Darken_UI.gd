extends ColorRect


func ChangeSize (dimension, newPosition):
	material.set_shader_parameter("cutout_position", newPosition)
	material.set_shader_parameter("cutout_size", dimension)
