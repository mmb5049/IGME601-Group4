extends Control
class_name ActionDockUI

const HEX_DISPLAY_SCENE := preload("res://UI/AbilityHexDisplayUI.tscn")
const DIRECTION_EDGES_SCENE := preload("res://UI/AbilityDirectionEdgesUI.tscn")

## The queue stays a separate editor-authored component. This path is exposed
## so another scene can relocate either component without changing this script.
@export var ability_sequence_path: NodePath = NodePath("../AbilitySequenceUI")

@export_category("Dock Transitions")
@export_range(0.05, 1.0, 0.01, "suffix:s") var enter_duration: float = 0.28
@export_range(0.05, 1.0, 0.01, "suffix:s") var exit_duration: float = 0.24
@export_range(0.05, 1.5, 0.01, "suffix:s") var queue_transfer_duration: float = 0.42
## Portion of the flight used to crossfade the direction glow from the large
## indicator's outer artwork to the queue Item's inset artwork.
@export_range(0.1, 1.0, 0.05) var direction_glow_transition_ratio: float = 0.75
@export_range(0.0, 256.0, 1.0, "suffix:px") var offscreen_margin: float = 32.0
@export_range(0.0, 1.0, 0.05) var cancelled_indicator_scale: float = 0.25

var _sequence: AbilitySequenceUI
var _dock_position: Vector2
var _indicator_offscreen_position: Vector2
var _execute_offscreen_position: Vector2
var _targeting_active: bool = false
var _committing_target: bool = false
var _active_transfer_entry_id: int = -1
var _active_flying_display: AbilityHexDisplayUI
var _transition_tween: Tween

@onready var _execute_button: ExecuteButtonUI = %ExecuteButtonUI
@onready var _indicator: OperationIndicatorUI = %OperationIndicatorUI
@onready var _transition_layer: Node2D = %TransitionLayer


func _ready() -> void:
	_sequence = get_node_or_null(ability_sequence_path) as AbilitySequenceUI
	if _sequence == null:
		push_error("ActionDockUI needs a valid AbilitySequenceUI path.")

	_execute_button.set_interaction_enabled(false)
	# Anchored Controls receive their final positions after the first layout
	# pass. Recording them here guarantees both visuals share the exact dock.
	await get_tree().process_frame
	_dock_position = _execute_button.position
	_indicator_offscreen_position = Vector2(
		-_indicator.size.x - offscreen_margin,
		_dock_position.y
	)
	_execute_offscreen_position = Vector2(
		_dock_position.x,
		get_viewport_rect().size.y + offscreen_margin
	)
	_indicator.position = _indicator_offscreen_position
	_indicator.hide_indicator()
	_execute_button.set_interaction_enabled(true)


## Connected to PlayerController.targeting_started by the Arena scene.
func begin_targeting(ability: Ability) -> void:
	if ability == null:
		return

	# A very fast second selection must not strand the previous queue Item in
	# its hidden placeholder state. Complete that hand-off before reusing the
	# shared dock for the new Ability.
	_complete_active_transfer_immediately()
	_kill_transition()
	_execute_button.set_interaction_enabled(false)
	_targeting_active = true
	_committing_target = false
	_indicator.position = _indicator_offscreen_position
	_indicator.scale = Vector2.ONE
	_indicator.show_targeting(ability)

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(
		_execute_button, "position", _execute_offscreen_position, enter_duration
	)
	_transition_tween.tween_property(
		_indicator, "position", _dock_position, enter_duration
	)


func set_target_preview(target: AbilityTarget) -> void:
	_indicator.set_target_preview(target)


## Confirmation reserves an invisible row, then transfers a temporary visual
## from the operation dock to that row. The real Item is revealed only when
## the transfer arrives, replacing the old small-to-large entrance animation.
func commit_confirmed_ability(ability: Ability, target: AbilityTarget) -> void:
	if _sequence == null or ability == null or target == null or not target.is_valid:
		return

	# Whether this Ability needs the operation-indicator transfer is determined
	# by its own targeting type, not by the dock's animation state. For example,
	# Wait can be clicked while another icon is still flying. It must append
	# normally without replacing that transfer's Tween or temporary visual.
	if ability.targeting_type == Global.TargetingType.NONE:
		_sequence.add_confirmed_ability(ability, target)
		return

	# A targeted confirmation should normally follow begin_targeting. Keeping
	# this guard prevents external callers from creating a transfer with no
	# visible indicator to use as its starting point.
	if not _targeting_active:
		_sequence.add_confirmed_ability(ability, target)
		return

	_committing_target = true
	var entry_id: int = _sequence.add_confirmed_ability_pending(ability, target)
	if entry_id < 0:
		_finish_commit_state()
		return

	var start_position: Vector2 = _indicator.get_display_global_position()
	var start_scale: Vector2 = _indicator.get_display_global_scale()
	var target_position: Vector2 = await _sequence.wait_for_entry_visual_position(entry_id)
	if not target_position.is_finite():
		_sequence.reveal_pending_entry(entry_id)
		_finish_commit_state()
		return

	var flying_display := HEX_DISPLAY_SCENE.instantiate() as AbilityHexDisplayUI
	_transition_layer.add_child(flying_display)
	flying_display.set_ability(ability)
	var flying_outer_edges: AbilityDirectionEdgesUI
	var flying_inner_edges: AbilityDirectionEdgesUI
	# A directional transfer carries two overlaid glow components. Crossfading
	# them during the flight avoids an abrupt outer-to-inner artwork swap.
	if ability.targeting_type == Global.TargetingType.DIRECTION:
		var direction_index: int = HexGrid.DIRECTIONS.find(target.direction)
		if direction_index >= 0:
			flying_outer_edges = (
				DIRECTION_EDGES_SCENE.instantiate() as AbilityDirectionEdgesUI
			)
			flying_display.add_child(flying_outer_edges)
			flying_outer_edges.show_direction(
				direction_index,
				target.is_valid,
				0.0
			)

			flying_inner_edges = (
				DIRECTION_EDGES_SCENE.instantiate() as AbilityDirectionEdgesUI
			)
			flying_inner_edges.use_inner_green = true
			flying_display.add_child(flying_inner_edges)
			flying_inner_edges.show_direction(
				direction_index,
				target.is_valid,
				0.0
			)
			flying_inner_edges.modulate = Color(1.0, 1.0, 1.0, 0.0)
	flying_display.global_position = start_position
	flying_display.global_scale = start_scale
	_active_transfer_entry_id = entry_id
	_active_flying_display = flying_display

	# Keep the source visible until the fully configured flying copy has taken
	# part in a rendered frame. The two visuals overlap exactly, so this creates
	# a seamless hand-off instead of a one-frame gap.
	await RenderingServer.frame_post_draw
	if (
		_active_transfer_entry_id != entry_id
		or not is_instance_valid(flying_display)
	):
		return
	_indicator.hide_indicator()

	_kill_transition()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(
		flying_display, "global_position", target_position, queue_transfer_duration
	)
	_transition_tween.tween_property(
		flying_display,
		"scale",
		_sequence.get_entry_visual_scale(entry_id),
		queue_transfer_duration
	)
	_transition_tween.tween_property(
		_execute_button, "position", _dock_position, exit_duration
	)
	if is_instance_valid(flying_outer_edges) and is_instance_valid(flying_inner_edges):
		var glow_transition_duration: float = (
			queue_transfer_duration * direction_glow_transition_ratio
		)
		_transition_tween.tween_property(
			flying_outer_edges,
			"modulate",
			Color(1.0, 1.0, 1.0, 0.0),
			glow_transition_duration
		)
		_transition_tween.tween_property(
			flying_inner_edges,
			"modulate",
			Color.WHITE,
			glow_transition_duration
		)
	await _transition_tween.finished

	# The transfer can be completed early when another Ability is selected.
	# In that case its replacement animation already revealed the real Item.
	if _active_transfer_entry_id != entry_id:
		return
	_sequence.reveal_pending_entry(entry_id)
	if is_instance_valid(flying_display):
		flying_display.queue_free()
	_finish_commit_state()


## Connected to PlayerController.targeting_ended. A confirmation emits this
## immediately after ability_confirmed, so the commit flag prevents the cancel
## transition from interrupting the transfer animation.
func end_targeting() -> void:
	if _committing_target or not _targeting_active:
		return

	_kill_transition()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(
		_indicator, "position", _indicator_offscreen_position, exit_duration
	)
	_transition_tween.tween_property(
		_indicator,
		"scale",
		Vector2.ONE * cancelled_indicator_scale,
		exit_duration
	)
	_transition_tween.tween_property(
		_execute_button, "position", _dock_position, exit_duration
	)
	await _transition_tween.finished
	_indicator.hide_indicator()
	_indicator.scale = Vector2.ONE
	_targeting_active = false
	_execute_button.set_interaction_enabled(true)


func _finish_commit_state() -> void:
	_indicator.hide_indicator()
	_indicator.position = _indicator_offscreen_position
	_indicator.scale = Vector2.ONE
	_execute_button.position = _dock_position
	_targeting_active = false
	_committing_target = false
	_active_transfer_entry_id = -1
	_active_flying_display = null
	_execute_button.set_interaction_enabled(true)


func _complete_active_transfer_immediately() -> void:
	if _active_transfer_entry_id < 0:
		return
	if _sequence != null:
		_sequence.reveal_pending_entry(_active_transfer_entry_id)
	if is_instance_valid(_active_flying_display):
		_active_flying_display.queue_free()
	_active_transfer_entry_id = -1
	_active_flying_display = null
	_committing_target = false


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
