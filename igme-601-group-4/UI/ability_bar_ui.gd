extends Control
class_name AbilityBarUI

## Forwarded when the player clicks a non-empty Slot. The Bar keeps its
## Ability; consumers such as AbilitySequenceUI decide what to do with it.
signal ability_selected(ability: Ability)

## Each array entry creates one slot. Null entries create empty slots, so this
## array is the single source of truth for both slot count and slot contents.
@export var abilities: Array[Ability] = []

## The visual slot component to instantiate. Developers may replace it with
## another compatible scene without rebuilding the Bar layout.
@export var slot_scene: PackedScene = preload("res://UI/AbilitySlotUI.tscn")

## Degrees added for every step away from the center of the Bar.
## Slots on the left receive negative rotation; slots on the right receive
## positive rotation. Set this to 0 to disable the fan effect.
@export_range(0.0, 15.0, 0.5) var rotation_step_degrees: float = 2.0

## Maximum number of pixels that the outermost Slots move downward. A squared
## falloff creates a subtle curved baseline instead of a straight V shape.
@export_range(0.0, 64.0, 1.0) var curve_depth_pixels: float = 14.0

## Distance and speed of each Slot's gentle floating animation.
@export_range(0.0, 16.0, 0.5) var breathing_amplitude_pixels: float = 3.0
@export_range(0.0, 2.0, 0.05) var breathing_speed_hz: float = 0.45

## Random phases make the Slots float independently. Set a non-zero seed for
## reproducible animation; zero produces a different arrangement each run.
@export var randomize_breathing_phase: bool = true
@export var breathing_random_seed: int = 0

## Used only when random phases are disabled.
@export_range(0.0, 3.14, 0.05) var breathing_phase_step: float = 0.55

## Minimum lift reached by a fully hovered Slot along its rotated local upward
## axis. Downward breathing cannot reduce this distance. Transition time
## controls how quickly it rises and returns instead of snapping instantly.
@export_range(0.0, 64.0, 1.0) var hover_lift_pixels: float = 18.0
@export_range(0.01, 1.0, 0.01) var hover_transition_seconds: float = 0.16

@onready var _slot_container: HBoxContainer = %SlotContainer

var _interaction_enabled: bool = true


func _ready() -> void:
	rebuild_slots()


## Recreates only the repeated slot instances. The Bar layout itself remains
## authored with normal Godot UI components in AbilityBarUI.tscn.
func rebuild_slots() -> void:
	for child in _slot_container.get_children():
		_slot_container.remove_child(child)
		child.queue_free()

	if slot_scene == null:
		push_warning("AbilityBarUI needs a Slot Scene before it can build slots.")
		return

	# A fractional center keeps even-sized Bars symmetrical. For example, six
	# slots use center index 2.5 and rotate by -5, -3, -1, 1, 3, and 5 degrees.
	var center_index: float = (float(abilities.size()) - 1.0) * 0.5
	var maximum_distance: float = maxf(center_index, 0.0)
	var phase_random := RandomNumberGenerator.new()
	phase_random.seed = breathing_random_seed
	if breathing_random_seed == 0:
		phase_random.seed = get_instance_id()

	for index in range(abilities.size()):
		var slot := slot_scene.instantiate() as AbilitySlotUI
		if slot == null:
			push_error("AbilityBarUI Slot Scene must have an AbilitySlotUI root.")
			return

		slot.configure(abilities[index])
		slot.set_interaction_enabled(_interaction_enabled)

		var signed_distance: float = float(index) - center_index
		var normalized_distance: float = 0.0
		if maximum_distance > 0.0:
			normalized_distance = absf(signed_distance) / maximum_distance
		var curve_offset: float = (
			normalized_distance * normalized_distance * curve_depth_pixels
		)
		var breathing_phase: float = float(index) * breathing_phase_step
		if randomize_breathing_phase:
			breathing_phase = phase_random.randf_range(0.0, TAU)

		# VisualRoot receives transforms because HBoxContainer controls the Slot's
		# root transform and would reset rotation or position during layout.
		slot.configure_visual_effects(
			signed_distance * rotation_step_degrees,
			curve_offset,
			breathing_amplitude_pixels,
			breathing_speed_hz,
			breathing_phase,
			hover_lift_pixels,
			hover_transition_seconds
		)
		slot.ability_pressed.connect(_on_slot_ability_pressed)
		_slot_container.add_child(slot)


func _on_slot_ability_pressed(ability: Ability) -> void:
	if not _interaction_enabled:
		return
	ability_selected.emit(ability)


## Planning input is locked while queued actions are resolving. Empty visual
## animation continues so the HUD does not appear frozen during execution.
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	for child in _slot_container.get_children():
		var slot: AbilitySlotUI = child as AbilitySlotUI
		if slot != null:
			slot.set_interaction_enabled(enabled)
