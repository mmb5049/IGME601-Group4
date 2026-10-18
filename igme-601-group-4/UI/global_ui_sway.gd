extends Control
class_name GlobalUISway

## Maximum offset applied when the cursor reaches a viewport edge. Keeping
## this value small prevents the motion from competing with gameplay input.
@export var maximum_sway_pixels: Vector2 = Vector2(8.0, 6.0)

## Higher values make the UI catch up to the cursor faster. Exponential
## smoothing keeps the result independent from frame rate.
@export_range(0.1, 30.0, 0.1, "suffix:Hz") var follow_speed: float = 6.0

## Moving opposite the cursor creates a subtle depth/parallax impression.
## Disable this if the UI should lean in the same direction as the cursor.
@export var invert_direction: bool = true

@onready var _sway_layer: Control = %SwayLayer


func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var target_offset := Vector2.ZERO
	if viewport_rect.has_point(mouse_position):
		var half_size: Vector2 = viewport_size * 0.5
		var normalized_mouse := Vector2(
			clampf((mouse_position.x - half_size.x) / half_size.x, -1.0, 1.0),
			clampf((mouse_position.y - half_size.y) / half_size.y, -1.0, 1.0)
		)
		target_offset = normalized_mouse * maximum_sway_pixels
		if invert_direction:
			target_offset = -target_offset

	# This form of interpolation feels the same at 30, 60, or 144 FPS and
	# returns smoothly to the center when the cursor leaves the game window.
	var smoothing_weight: float = 1.0 - exp(-follow_speed * delta)
	_sway_layer.position = _sway_layer.position.lerp(target_offset, smoothing_weight)
