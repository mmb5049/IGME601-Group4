extends Button
class_name ExecuteButtonUI

## ActionExecutionController listens to the dock's execution request.
signal execute_requested

@export_range(0.01, 0.5, 0.01, "suffix:s") var hover_duration: float = 0.12
@export_range(1.0, 1.25, 0.01) var hover_scale_multiplier: float = 1.06

var _visual_tween: Tween
var _normal_scale: Vector2
var _interaction_enabled: bool = true
var _dock_available: bool = true

@onready var _visual: AbilityHexDisplayUI = %ActionDisplay


func _ready() -> void:
	_normal_scale = _visual.scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)


func _has_point(point: Vector2) -> bool:
	# Match the hex mask at rest so the queue can receive input in the
	# transparent upper-left corner of the button's rectangular bounds.
	var hex_point: Vector2 = (point - _visual.position).abs() / (_normal_scale * 128.0)
	return maxf(hex_point.x / 0.8660254, hex_point.x * 0.5773503 + hex_point.y) <= 0.5


func _on_pressed() -> void:
	execute_requested.emit()


## The turn controller and dock can each lock the button independently.
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	disabled = not (_interaction_enabled and _dock_available)


func set_dock_available(available: bool) -> void:
	_dock_available = available
	disabled = not (_interaction_enabled and _dock_available)


func _on_mouse_entered() -> void:
	_animate_scale(_normal_scale * hover_scale_multiplier)


func _on_mouse_exited() -> void:
	_animate_scale(_normal_scale)


func _animate_scale(target_scale: Vector2) -> void:
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	_visual_tween = create_tween()
	_visual_tween.set_trans(Tween.TRANS_QUAD)
	_visual_tween.set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(_visual, "scale", target_scale, hover_duration)
