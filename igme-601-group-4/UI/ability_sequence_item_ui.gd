extends Control
class_name AbilitySequenceItemUI

## The Sequence owns queue data. An Item only requests removal by stable ID.
signal removal_requested(entry_id: int)

## Requests that one stable queue entry be inserted before or after this Item.
## The Sequence remains responsible for changing the underlying data order.
signal reorder_requested(
	dragged_entry_id: int,
	target_entry_id: int,
	insert_after: bool
)

## These signals let the Sequence animate a temporary insertion gap while an
## entry is being dragged without changing the actual queue until mouse-up.
signal drag_started(entry_id: int)
signal drag_finished(
	entry_id: int,
	release_global_position: Vector2,
	should_return_to_slot: bool
)
signal reorder_preview_requested(
	dragged_entry_id: int,
	target_entry_id: int,
	insert_after: bool
)

const HEX_DISPLAY_SCENE := preload("res://UI/AbilityHexDisplayUI.tscn")
const DIRECTION_EDGES_SCENE := preload("res://UI/AbilityDirectionEdgesUI.tscn")

## The two centers are separated by half of the visible hexagon width. Together
## with the SequenceContainer's vertical step, this makes neighboring hexagons
## share an edge instead of looking like disconnected rows.
const LEFT_HEX_POSITION := Vector2(52.0, 46.0)
const RIGHT_HEX_POSITION := Vector2(92.0, 46.0)

## Controls the entrance animation played only by a newly appended entry.
@export_range(0.05, 1.0, 0.01, "suffix:s") var appearance_duration: float = 0.22
@export_range(0.0, 1.0, 0.05) var appearance_start_scale_ratio: float = 0.15

## Drag-preview feedback for the removal area. The preview is tinted when the
## cursor leaves the same safe region used by the actual deletion check.
@export var removal_preview_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export_range(0.01, 0.5, 0.01, "suffix:s") var removal_color_transition: float = 0.14

var _entry_id: int = -1
var _ability: Ability
var _target: AbilityTarget
var _align_right: bool = false
var _drop_region: Control
var _drag_active: bool = false
var _animate_appearance: bool = false
var _pending_reveal: bool = false
var _normal_hex_scale: Vector2
var _reorder_offset_y: float = 0.0
var _has_preview_alignment: bool = false
var _preview_align_right: bool = false
var _reorder_tween: Tween
var _opacity_tween: Tween
var _drag_preview_hex: AbilityHexDisplayUI
var _drag_preview_is_removal: bool = false
var _drag_preview_color_tween: Tween
var _interaction_enabled: bool = true

@onready var _hex_display: AbilityHexDisplayUI = $AbilityHexDisplayUI
@onready var _direction_edges: AbilityDirectionEdgesUI = %DirectionEdges


func _ready() -> void:
	set_process(false)
	_normal_hex_scale = _hex_display.scale
	_refresh_display()
	# A targeting confirmation reserves its final queue row before the large
	# indicator flies into it. Keeping only the visual hidden lets VBoxContainer
	# calculate the correct destination without showing a duplicate icon.
	_hex_display.visible = not _pending_reveal
	if _animate_appearance:
		_play_appearance_animation()


## Configures one queue entry. Alternating alignment produces the linked
## hexagon pattern while the VBoxContainer still controls vertical ordering.
func configure(
	entry_id: int,
	ability: Ability,
	target: AbilityTarget,
	align_right: bool,
	drop_region: Control,
	animate_appearance: bool = false,
	pending_reveal: bool = false
) -> void:
	_entry_id = entry_id
	_ability = ability
	_target = target
	_align_right = align_right
	_drop_region = drop_region
	_animate_appearance = animate_appearance
	_pending_reveal = pending_reveal
	_refresh_display()


func _refresh_display() -> void:
	if not is_node_ready():
		return

	_hex_display.position = _get_hex_position_with_reorder_offset()
	_hex_display.set_ability(_ability)
	_configure_direction_edges(_direction_edges)
	tooltip_text = _ability.ability_name if _ability else "Empty Queue Entry"


## Queue entries preserve their confirmed AbilityTarget. Directional entries
## therefore show a fixed green edge matching the direction that will execute.
func _configure_direction_edges(edges: AbilityDirectionEdgesUI) -> void:
	edges.hide_directions(false)
	if (
		_ability == null
		or _ability.targeting_type != Global.TargetingType.DIRECTION
		or _target == null
	):
		return

	var direction_index: int = HexGrid.DIRECTIONS.find(_target.direction)
	if direction_index >= 0:
		edges.show_direction(direction_index, _target.is_valid, 0.0)


func _get_hex_position_with_reorder_offset() -> Vector2:
	var align_right: bool = _preview_align_right if _has_preview_alignment else _align_right
	var base_position: Vector2 = RIGHT_HEX_POSITION if align_right else LEFT_HEX_POSITION
	return base_position + Vector2(0.0, _reorder_offset_y)


## The shared hex display is centered on its Node2D origin, so scaling it here
## makes the Ability grow evenly outward from the middle of the hexagon.
func _play_appearance_animation() -> void:
	_hex_display.scale = _normal_hex_scale * appearance_start_scale_ratio
	var tween: Tween = create_tween()
	# Cubic easing reaches the normal size smoothly without overshooting the
	# ScrollContainer's clipping boundary at the top of the sequence.
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		_hex_display,
		"scale",
		_normal_hex_scale,
		appearance_duration
	)


## Only sequence items are draggable. The bottom Ability Bar remains static.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _interaction_enabled or _ability == null:
		return null

	_drag_active = true
	drag_started.emit(_entry_id)
	# A zero-sized preview root places its origin exactly at the cursor. Because
	# AbilityHexDisplayUI draws around its Node2D origin, the icon is centered on
	# the cursor instead of appearing below and to its right.
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_hex := HEX_DISPLAY_SCENE.instantiate() as AbilityHexDisplayUI
	preview_hex.position = Vector2.ZERO
	preview_hex.scale = Vector2(0.72, 0.72)
	preview_hex.set_ability(_ability)
	preview.add_child(preview_hex)
	var preview_edges := DIRECTION_EDGES_SCENE.instantiate() as AbilityDirectionEdgesUI
	preview_edges.use_inner_green = true
	preview_hex.add_child(preview_edges)
	# Drag previews are assembled before their temporary Control enters the
	# scene tree, so wait for the overlay's @onready references before styling it.
	preview_edges.ready.connect(
		_configure_direction_edges.bind(preview_edges),
		CONNECT_ONE_SHOT
	)
	_drag_preview_hex = preview_hex
	_drag_preview_is_removal = false
	set_process(true)
	set_drag_preview(preview)

	return {
		"queue_entry_id": _entry_id,
	}


## Sequence execution locks drag creation at the Item itself. This is safer
## than merely ignoring reorder signals after a drag preview already exists.
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled


## Checks the cursor continuously because drag-and-drop callbacks only run
## while a Control is acting as a drop target. Color feedback must also update
## while the cursor is outside the sequence, where releasing removes the Item.
func _process(_delta: float) -> void:
	if not _drag_active or not is_instance_valid(_drag_preview_hex):
		return
	if not is_instance_valid(_drop_region):
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var is_removal_position: bool = not _drop_region.get_global_rect().has_point(mouse_position)
	if is_removal_position == _drag_preview_is_removal:
		return

	_drag_preview_is_removal = is_removal_position
	_animate_drag_preview_color(
		removal_preview_color if is_removal_position else Color.WHITE
	)


func _animate_drag_preview_color(target_color: Color) -> void:
	if not is_instance_valid(_drag_preview_hex):
		return

	if _drag_preview_color_tween != null and _drag_preview_color_tween.is_valid():
		_drag_preview_color_tween.kill()

	_drag_preview_color_tween = create_tween()
	_drag_preview_color_tween.set_trans(Tween.TRANS_QUAD)
	_drag_preview_color_tween.set_ease(Tween.EASE_OUT)
	_drag_preview_color_tween.tween_property(
		_drag_preview_hex,
		"modulate",
		target_color,
		removal_color_transition
	)


## A queue Item accepts another queue entry as a reorder operation. Dropping
## on the upper half inserts before this Item; the lower half inserts after it.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false

	var dragged_entry_id: int = int(data.get("queue_entry_id", -1))
	if dragged_entry_id < 0:
		return false

	var insert_after: bool = at_position.y >= size.y * 0.5
	reorder_preview_requested.emit(dragged_entry_id, _entry_id, insert_after)
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return

	var dragged_entry_id: int = int(data.get("queue_entry_id", -1))
	var insert_after: bool = at_position.y >= size.y * 0.5
	reorder_requested.emit(dragged_entry_id, _entry_id, insert_after)


## Moves the visual child to its complete temporary queue layout. Both axes
## are updated: Y opens/closes the insertion row, while X follows the new
## index's alternating left/right honeycomb alignment.
func set_reorder_preview_layout(
	align_right: bool,
	offset_y: float,
	duration: float
) -> void:
	var alignment_unchanged: bool = (
		_has_preview_alignment and _preview_align_right == align_right
	)
	if alignment_unchanged and is_equal_approx(_reorder_offset_y, offset_y):
		return

	_has_preview_alignment = true
	_preview_align_right = align_right
	_reorder_offset_y = offset_y
	_animate_to_current_layout(duration)


func clear_reorder_preview_layout(duration: float) -> void:
	if not _has_preview_alignment and is_zero_approx(_reorder_offset_y):
		return

	_has_preview_alignment = false
	_reorder_offset_y = 0.0
	_animate_to_current_layout(duration)


## Replaces the temporary drag preview at the cursor when a safe drop does not
## change the queue order. The real hex becomes visible at the exact release
## point and travels back to its unchanged slot instead of snapping there.
func animate_drag_return_from_global_position(
	start_position: Vector2,
	duration: float
) -> void:
	if not is_node_ready():
		return

	if _reorder_tween != null and _reorder_tween.is_valid():
		_reorder_tween.kill()
	if _opacity_tween != null and _opacity_tween.is_valid():
		_opacity_tween.kill()

	_has_preview_alignment = false
	_reorder_offset_y = 0.0
	var target_position := _get_hex_position_with_reorder_offset()
	_hex_display.global_position = start_position
	_hex_display.modulate = Color.WHITE
	_hex_display.visible = true

	if duration <= 0.0 or _hex_display.position.distance_squared_to(target_position) < 0.01:
		_hex_display.position = target_position
		return

	_reorder_tween = create_tween()
	_reorder_tween.set_trans(Tween.TRANS_QUAD)
	_reorder_tween.set_ease(Tween.EASE_OUT)
	_reorder_tween.tween_property(
		_hex_display,
		"position",
		target_position,
		duration
	)


func _animate_to_current_layout(duration: float) -> void:
	if not is_node_ready():
		return

	if _reorder_tween != null and _reorder_tween.is_valid():
		_reorder_tween.kill()

	if duration <= 0.0:
		_hex_display.position = _get_hex_position_with_reorder_offset()
		return

	_reorder_tween = create_tween()
	_reorder_tween.set_trans(Tween.TRANS_QUAD)
	_reorder_tween.set_ease(Tween.EASE_OUT)
	_reorder_tween.tween_property(
		_hex_display,
		"position",
		_get_hex_position_with_reorder_offset(),
		duration
	)


## The source disappears immediately while it is attached to the cursor, so
## its original queue row becomes a genuinely empty slot. If a drag is
## cancelled, the source fades back into that slot.
func set_drag_source_active(active: bool, duration: float) -> void:
	if not is_node_ready():
		return

	if _opacity_tween != null and _opacity_tween.is_valid():
		_opacity_tween.kill()

	if active:
		_hex_display.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return

	var target_modulate := Color.WHITE
	if duration <= 0.0:
		_hex_display.modulate = target_modulate
		return

	_opacity_tween = create_tween()
	_opacity_tween.set_trans(Tween.TRANS_QUAD)
	_opacity_tween.set_ease(Tween.EASE_OUT)
	_opacity_tween.tween_property(_hex_display, "modulate", target_modulate, duration)


func get_entry_id() -> int:
	return _entry_id


func set_frame_color(color: Color) -> void:
	_hex_display.set_frame_color(color)


## Shared exit effect for player and enemy queue entries. The owner detaches
## the item from its layout before playing this non-interactive visual tail.
func play_removal_animation(duration: float = 0.20) -> void:
	set_interaction_enabled(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _reorder_tween != null and _reorder_tween.is_valid():
		_reorder_tween.kill()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hex_display, "scale", Vector2.ZERO, duration)
	tween.tween_property(_hex_display, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)


func get_hex_global_position() -> Vector2:
	return _hex_display.global_position


func get_hex_screen_polygon() -> PackedVector2Array:
	# Same point-up hex geometry as hex_ui_mask.gdshader, including animations.
	var polygon := PackedVector2Array([
		Vector2(0, -64), Vector2(55.4256, -32), Vector2(55.4256, 32),
		Vector2(0, 64), Vector2(-55.4256, 32), Vector2(-55.4256, -32),
	])
	return _hex_display.get_global_transform_with_canvas() * polygon


func get_hex_scale() -> Vector2:
	return _normal_hex_scale if _normal_hex_scale != Vector2.ZERO else _hex_display.scale


## Completes the visual hand-off from OperationIndicatorUI. The Item has
## occupied its row throughout the transfer, so revealing it cannot disturb
## the queue layout.
func reveal_pending_visual() -> void:
	_pending_reveal = false
	if is_node_ready():
		_hex_display.visible = true
		_hex_display.modulate = Color.WHITE


## Keeps a rebuilt Item visible at its old screen position while its Container
## calculates the new row. Making the display top-level temporarily prevents
## the parent Control's intermediate layout from moving it for one frame.
func hold_layout_transition_at_global_position(start_position: Vector2) -> void:
	if not is_node_ready():
		return

	if _reorder_tween != null and _reorder_tween.is_valid():
		_reorder_tween.kill()

	var held_transform := _hex_display.global_transform
	_hex_display.top_level = true
	_hex_display.global_transform = held_transform
	_hex_display.global_position = start_position
	_hex_display.visible = true


## Used after the data order changes. A newly rebuilt Item starts visually at
## its previous screen position, then travels to the position assigned by its
## new queue index and left/right alignment.
func animate_from_global_position(start_position: Vector2, duration: float, delay: float = 0.0) -> void:
	if not is_node_ready():
		return

	if _reorder_tween != null and _reorder_tween.is_valid():
		_reorder_tween.kill()

	# Preserve the held global transform while returning the display to its new
	# parent row. Releasing top_level without doing this would itself create a
	# one-frame jump when the Container has moved the Item.
	if _hex_display.top_level:
		var held_transform := _hex_display.global_transform
		_hex_display.top_level = false
		_hex_display.global_transform = held_transform
	else:
		_hex_display.global_position = start_position

	# The destination is the Item's known local hex position, not a sampled
	# global position. This guarantees every animation finishes inside its own
	# queue row even if the parent Container performs another layout pass.
	var target_position: Vector2 = _get_hex_position_with_reorder_offset()
	_hex_display.visible = true
	if _hex_display.position.distance_squared_to(target_position) < 0.01:
		_hex_display.position = target_position
		return

	_reorder_tween = create_tween()
	_reorder_tween.set_trans(Tween.TRANS_QUAD)
	_reorder_tween.set_ease(Tween.EASE_OUT)
	_reorder_tween.tween_property(
		_hex_display,
		"position",
		target_position,
		duration
	).set_delay(delay)


## Godot notifies the source Control when a drag finishes. The Item delegates
## deletion to AbilitySequenceUI only when released outside its valid region.
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _drag_active:
		return

	_drag_active = false
	set_process(false)
	if _drag_preview_color_tween != null and _drag_preview_color_tween.is_valid():
		_drag_preview_color_tween.kill()
	_drag_preview_hex = null
	_drag_preview_is_removal = false

	var mouse_position := get_viewport().get_mouse_position()
	var is_removal_position := (
		is_instance_valid(_drop_region)
		and not _drop_region.get_global_rect().has_point(mouse_position)
	)
	drag_finished.emit(_entry_id, mouse_position, not is_removal_position)
	if is_removal_position:
		removal_requested.emit(_entry_id)
