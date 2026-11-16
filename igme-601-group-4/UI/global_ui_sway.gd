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
	var target_offset := get_normalized_mouse_position(get_viewport()) * maximum_sway_pixels
	if invert_direction:
		target_offset = -target_offset

	# This form of interpolation feels the same at 30, 60, or 144 FPS and
	# returns smoothly to the center when the cursor leaves the game window.
	var smoothing_weight: float = 1.0 - exp(-follow_speed * delta)
	_sway_layer.position = _sway_layer.position.lerp(target_offset, smoothing_weight)


## UI and camera motion use the same CRT-adjusted coordinates and viewport bounds.
static func get_normalized_mouse_position(viewport: Viewport) -> Vector2:
	var bounds := viewport.get_visible_rect()
	if not bounds.has_point(viewport.get_mouse_position()):
		return Vector2.ZERO
	# CRT curvature can map a cursor at a visible corner beyond the content bounds.
	var mouse := CRTOverlay.get_content_mouse_position(viewport)
	var normalized := (mouse - bounds.get_center()) / (bounds.size * 0.5)
	return normalized.clamp(-Vector2.ONE, Vector2.ONE)
