extends ColorRect

@export var padding: Vector2 = Vector2(15, 15)

func ChangeSize(target: Control) -> void:
	var rect: Rect2 = target.get_global_rect()

	var center: Vector2 = rect.position + rect.size / 2.0

	material.set_shader_parameter(
		"cutout_position",
		center
	)
