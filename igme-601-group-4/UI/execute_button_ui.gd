extends Control
class_name ExecuteButtonUI

## Consumers listen to this semantic signal instead of depending on the
## internal Button node. ActionExecutionController currently consumes it.
signal execute_requested

@export_range(0.01, 0.5, 0.01, "suffix:s") var hover_duration: float = 0.12
@export_range(1.0, 1.25, 0.01) var hover_scale_multiplier: float = 1.06

var _visual_tween: Tween
var _normal_scale: Vector2

@onready var _button: Button = %ExecuteButton
@onready var _visual: AbilityHexDisplayUI = %ActionDisplay


func _ready() -> void:
	_normal_scale = _visual.scale
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	execute_requested.emit()


## Used both while selecting a target and while an action queue is executing.
## Keeping the lock inside this reusable component prevents programmatic or
## rapid repeated presses from bypassing the visual dock state.
func set_interaction_enabled(enabled: bool) -> void:
	_button.disabled = not enabled


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
