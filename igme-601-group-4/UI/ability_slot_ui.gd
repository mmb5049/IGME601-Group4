extends Control
class_name AbilitySlotUI

## Sent when the player clicks a non-empty Bar Slot.
signal ability_pressed(ability: Ability)

## Ability currently displayed by this slot. A null value represents an empty slot.
@export var ability: Ability

var _visual_rotation_degrees: float = 0.0
var _curve_offset_y: float = 0.0
var _breathing_amplitude: float = 0.0
var _breathing_speed_hz: float = 0.0
var _breathing_phase: float = 0.0
var _breathing_time: float = 0.0
var _hover_lift_distance: float = 0.0
var _hover_transition_seconds: float = 0.0
var _hover_target: float = 0.0
var _hover_progress: float = 0.0
var _interaction_enabled: bool = true

@onready var _hex_display: AbilityHexDisplayUI = $AbilityHexDisplayUI


func _ready() -> void:
	# HBoxContainer owns this component's root transform. HexDisplay is a Node2D
	# so animation can use smooth subpixel motion instead of pixel-snapped UI
	# coordinates, while the outer Control still handles layout and input.
	resized.connect(_apply_visual_transform.bind(0.0))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_visual_transform(0.0)
	_refresh_display()


func _process(delta: float) -> void:
	_breathing_time += delta
	var breathing_offset := sin(
		_breathing_time * TAU * _breathing_speed_hz + _breathing_phase
	) * _breathing_amplitude
	var transition_duration: float = maxf(_hover_transition_seconds, 0.001)
	_hover_progress = move_toward(
		_hover_progress,
		_hover_target,
		delta / transition_duration
	)
	_apply_visual_transform(breathing_offset)


## Configures the fan rotation, curved baseline, breathing, and hover lift.
## Animated movement follows the Slot's rotated local Y axis rather than screen Y.
func configure_visual_effects(
	rotation_degrees_value: float,
	curve_offset_y: float,
	breathing_amplitude: float,
	breathing_speed_hz: float,
	breathing_phase: float,
	hover_lift_distance: float,
	hover_transition_seconds: float
) -> void:
	_visual_rotation_degrees = rotation_degrees_value
	_curve_offset_y = curve_offset_y
	_breathing_amplitude = breathing_amplitude
	_breathing_speed_hz = breathing_speed_hz
	_breathing_phase = breathing_phase
	_hover_lift_distance = hover_lift_distance
	_hover_transition_seconds = hover_transition_seconds
	_apply_visual_transform(0.0)


func _apply_visual_transform(breathing_offset: float) -> void:
	if not is_node_ready():
		return

	_hex_display.rotation_degrees = _visual_rotation_degrees

	# A rotated local Y axis is (-sin(angle), cos(angle)) in screen coordinates.
	# The curve always moves downward. Breathing and hover lift both follow the
	# rotated local axis; hover uses the negative direction to move upward.
	var angle_radians := deg_to_rad(_visual_rotation_degrees)
	var rotated_y_axis := Vector2(-sin(angle_radians), cos(angle_radians))
	var eased_hover: float = smoothstep(0.0, 1.0, _hover_progress)
	var required_hover_lift: float = _hover_lift_distance * eased_hover
	var local_axis_offset: float = breathing_offset - required_hover_lift

	# Downward breathing must not cancel the required hover lift. Upward
	# breathing is still allowed to raise the selected Slot beyond the minimum.
	if eased_hover > 0.0:
		local_axis_offset = minf(local_axis_offset, -required_hover_lift)
	_hex_display.position = (
		size * 0.5
		+ Vector2(0.0, _curve_offset_y)
		+ rotated_y_axis * local_axis_offset
	)


## Called by AbilityBarUI to connect this reusable visual component to its data.
func configure(new_ability: Ability) -> void:
	ability = new_ability
	_refresh_display()


func _gui_input(event: InputEvent) -> void:
	if not _interaction_enabled:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and ability != null:
		ability_pressed.emit(ability)
		accept_event()


## AbilityBarUI disables every Slot during action execution. The breathing
## animation remains active, but selection and hover emphasis are suppressed.
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled:
		_hover_target = 0.0
		z_index = 0


func _on_mouse_entered() -> void:
	_hover_target = 1.0
	z_index = 10


func _on_mouse_exited() -> void:
	_hover_target = 0.0
	z_index = 0


## Updates existing scene components; it does not create any UI nodes.
func _refresh_display() -> void:
	if not is_node_ready():
		return

	_hex_display.set_ability(ability)
	tooltip_text = ability.ability_name if ability else "Empty Ability Slot"
