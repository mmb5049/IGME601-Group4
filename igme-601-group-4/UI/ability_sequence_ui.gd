extends Control
class_name AbilitySequenceUI

## Emitted whenever an entry is added, removed, or reordered.
signal queue_changed

@export var item_scene: PackedScene = preload("res://UI/AbilitySequenceItemUI.tscn")

## Live reorder-preview settings. The default gap matches the approximately
## 69-pixel center spacing of the touching hexagon layout.
@export_range(0.0, 128.0, 1.0, "suffix:px") var reorder_gap_pixels: float = 69.0
@export_range(0.01, 0.5, 0.01, "suffix:s") var reorder_animation_duration: float = 0.14
@export_range(0.01, 0.75, 0.01, "suffix:s") var layout_animation_duration: float = 0.20

var queued_entries: Array[QueuedAbility] = []
var _next_entry_id: int = 1
var _active_drag_entry_id: int = -1
var _preview_insertion_index: int = -1
var _pending_reveal_entry_ids: Dictionary[int, bool] = {}
var _interaction_enabled: bool = true

@onready var _drop_region: Control = %SequenceDropRegion
@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _item_container: VBoxContainer = %SequenceContainer


## Connected to PlayerController after targeting is confirmed. Repeated Ability
## resources are allowed; each entry keeps its own target and stable ID.
func add_confirmed_ability(ability: Ability, target: AbilityTarget) -> void:
	if ability == null or target == null or not target.is_valid:
		return

	var added_entry_id: int = _next_entry_id
	queued_entries.append(QueuedAbility.new(added_entry_id, ability, target))
	_next_entry_id += 1
	_rebuild_items(added_entry_id)
	queue_changed.emit()


## Adds a confirmed targeted Ability without playing the Item's old pop-in
## animation. The returned stable ID lets ActionDockUI animate the large
## operation indicator into this reserved queue position.
func add_confirmed_ability_pending(ability: Ability, target: AbilityTarget) -> int:
	if ability == null or target == null or not target.is_valid:
		return -1

	var added_entry_id: int = _next_entry_id
	queued_entries.append(QueuedAbility.new(added_entry_id, ability, target))
	_pending_reveal_entry_ids[added_entry_id] = true
	_next_entry_id += 1
	_rebuild_items()
	queue_changed.emit()
	return added_entry_id


## Waits for both the VBoxContainer layout and any required scrolling before
## returning the destination used by the indicator-to-queue animation.
func wait_for_entry_visual_position(entry_id: int) -> Vector2:
	await RenderingServer.frame_pre_draw
	var item: AbilitySequenceItemUI = _find_item(entry_id)
	if item == null:
		return Vector2(INF, INF)

	_scroll_container.ensure_control_visible(item)
	await RenderingServer.frame_pre_draw
	item = _find_item(entry_id)
	return item.get_hex_global_position() if item != null else Vector2(INF, INF)


func get_entry_visual_scale(entry_id: int) -> Vector2:
	var item: AbilitySequenceItemUI = _find_item(entry_id)
	return item.get_hex_scale() if item != null else Vector2.ONE


func reveal_pending_entry(entry_id: int) -> void:
	_pending_reveal_entry_ids.erase(entry_id)
	var item: AbilitySequenceItemUI = _find_item(entry_id)
	if item != null:
		item.reveal_pending_visual()


## Compatibility helper for non-targeted callers. The formal AbilityBar flow
## uses add_confirmed_ability so targeted commands never lose their selection.
func add_ability(ability: Ability) -> void:
	if ability == null:
		return
	if ability.targeting_type != Global.TargetingType.NONE:
		push_warning(
			"Targeted abilities must use add_confirmed_ability so their target is preserved."
		)
		return

	var target := AbilityTarget.new(ability.targeting_type)
	target.is_valid = true
	add_confirmed_ability(ability, target)


func clear_queue() -> void:
	queued_entries.clear()
	_pending_reveal_entry_ids.clear()
	_rebuild_items()
	queue_changed.emit()


## Minimal queue-source contract used by ActionExecutionController. Returning
## the entry rather than only its Ability preserves the confirmed target and
## stable ID required to consume the correct repeated Ability instance.
func has_entries() -> bool:
	return not queued_entries.is_empty()


func peek_front_entry() -> QueuedAbility:
	return queued_entries.front() if has_entries() else null


## Removes one resolved action by stable ID and reuses the existing layout
## animation. The executor may call this while player editing is locked.
func consume_entry(entry_id: int) -> bool:
	var index: int = _find_entry_index(entry_id)
	if index < 0:
		return false

	var previous_positions: Dictionary[int, Vector2] = _capture_item_positions()
	queued_entries.remove_at(index)
	_pending_reveal_entry_ids.erase(entry_id)
	_rebuild_items()
	_animate_rebuilt_items(previous_positions)
	queue_changed.emit()
	return true


## Locks player-authored mutations during execution while leaving internal
## consumption available to the execution controller.
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled and _active_drag_entry_id >= 0:
		_clear_reorder_preview(false)
	for child in _item_container.get_children():
		var item: AbilitySequenceItemUI = child as AbilitySequenceItemUI
		if item != null:
			item.set_interaction_enabled(enabled)


func get_queued_abilities() -> Array[Ability]:
	var result: Array[Ability] = []
	for entry in queued_entries:
		result.append(entry.ability)
	return result


## Rebuilding keeps alternating alignment correct after deleting an entry from
## the middle of the queue. Only animated_entry_id receives an entrance
## animation, so existing entries do not replay it whenever the queue changes.
func _rebuild_items(animated_entry_id: int = -1) -> void:
	for child in _item_container.get_children():
		_item_container.remove_child(child)
		child.queue_free()

	if item_scene == null:
		push_warning("AbilitySequenceUI needs an Item Scene.")
		return

	for index in range(queued_entries.size()):
		var item := item_scene.instantiate() as AbilitySequenceItemUI
		if item == null:
			push_error("Sequence Item Scene must have an AbilitySequenceItemUI root.")
			return

		var entry := queued_entries[index]
		item.configure(
			entry.id,
			entry.ability,
			entry.target,
			index % 2 == 1,
			_drop_region,
			entry.id == animated_entry_id,
			_pending_reveal_entry_ids.has(entry.id)
		)
		item.set_interaction_enabled(_interaction_enabled)
		item.removal_requested.connect(_on_item_removal_requested)
		item.reorder_requested.connect(_on_item_reorder_requested)
		item.drag_started.connect(_on_item_drag_started)
		item.drag_finished.connect(_on_item_drag_finished)
		item.reorder_preview_requested.connect(_on_item_reorder_preview_requested)
		_item_container.add_child(item)


func _on_item_removal_requested(entry_id: int) -> void:
	if _interaction_enabled:
		consume_entry(entry_id)


## Moves a unique queue entry relative to another entry. The target index is
## resolved again after removal because removing an earlier item shifts every
## later array index by one.
func _on_item_reorder_requested(
	dragged_entry_id: int,
	target_entry_id: int,
	insert_after: bool
) -> void:
	if not _interaction_enabled:
		return
	# Dropping on the source's own placeholder confirms the existing position.
	# Drag-end will close the temporary gap and animate the cursor icon home.
	if dragged_entry_id == target_entry_id:
		return

	var previous_positions: Dictionary[int, Vector2] = _capture_item_positions()
	# The dragged entry must continue from the icon under the player's cursor,
	# not from the now-empty slot where that entry originally lived.
	previous_positions[dragged_entry_id] = get_global_mouse_position()
	_clear_reorder_preview(false)
	var source_index: int = _find_entry_index(dragged_entry_id)
	if source_index < 0:
		return

	var moved_entry: QueuedAbility = queued_entries[source_index]
	queued_entries.remove_at(source_index)

	var target_index: int = _find_entry_index(target_entry_id)
	if target_index < 0:
		# This should only happen if the queue changed during the drag. Restore the
		# entry instead of silently losing it.
		queued_entries.insert(source_index, moved_entry)
		return

	var insertion_index: int = target_index + 1 if insert_after else target_index
	queued_entries.insert(insertion_index, moved_entry)
	_rebuild_items()
	_animate_rebuilt_items(previous_positions)
	queue_changed.emit()


func _on_item_drag_started(entry_id: int) -> void:
	if not _interaction_enabled:
		return
	_active_drag_entry_id = entry_id
	_preview_insertion_index = -1
	_update_drag_source_appearance(true)


func _on_item_drag_finished(
	entry_id: int,
	release_global_position: Vector2,
	should_return_to_slot: bool
) -> void:
	if not _interaction_enabled:
		return
	if entry_id != _active_drag_entry_id:
		return

	if should_return_to_slot:
		_clear_reorder_preview(true, entry_id, release_global_position)
	else:
		_clear_reorder_preview(false)


## Opens one visual row at the proposed insertion boundary. Item Controls stay
## in place as reliable drop targets; only their hexagon visuals move.
func _on_item_reorder_preview_requested(
	dragged_entry_id: int,
	target_entry_id: int,
	insert_after: bool
) -> void:
	if not _interaction_enabled:
		return
	if dragged_entry_id != _active_drag_entry_id:
		return

	var source_index: int = _find_entry_index(dragged_entry_id)
	var target_index: int = _find_entry_index(target_entry_id)
	if source_index < 0 or target_index < 0:
		return

	# Calculate the insertion boundary in the compact queue that would remain
	# after removing the dragged entry. Returning to the source uses its existing
	# empty row, so no second gap is opened and no other Item needs to move.
	var insertion_index: int
	if dragged_entry_id == target_entry_id:
		insertion_index = source_index
	else:
		var compact_target_index: int = target_index
		if target_index > source_index:
			compact_target_index -= 1
		insertion_index = compact_target_index + 1 if insert_after else compact_target_index
		insertion_index = clampi(insertion_index, 0, queued_entries.size() - 1)

	if insertion_index == _preview_insertion_index:
		return

	_preview_insertion_index = insertion_index
	for index in range(_item_container.get_child_count()):
		var item: AbilitySequenceItemUI = _item_container.get_child(index) as AbilitySequenceItemUI
		if item == null:
			continue

		var entry_id: int = queued_entries[index].id
		if entry_id == _active_drag_entry_id:
			item.clear_reorder_preview_layout(reorder_animation_duration)
			continue

		# First close the source's empty row, then open one row at the proposed
		# insertion point. The result can move an Item up, down, or not at all.
		var compact_index: int = index - 1 if index > source_index else index
		var preview_index: int = compact_index
		if compact_index >= insertion_index:
			preview_index += 1
		var row_offset: int = preview_index - index
		item.set_reorder_preview_layout(
			preview_index % 2 == 1,
			float(row_offset) * reorder_gap_pixels,
			reorder_animation_duration
		)


func _clear_reorder_preview(
	animated: bool,
	return_entry_id: int = -1,
	return_global_position: Vector2 = Vector2.ZERO
) -> void:
	var duration: float = reorder_animation_duration if animated else 0.0
	for child in _item_container.get_children():
		var item: AbilitySequenceItemUI = child as AbilitySequenceItemUI
		if item == null:
			continue
		if item.get_entry_id() == return_entry_id:
			item.animate_drag_return_from_global_position(
				return_global_position,
				duration
			)
			continue
		item.clear_reorder_preview_layout(duration)
		item.set_drag_source_active(false, duration)

	_active_drag_entry_id = -1
	_preview_insertion_index = -1


func _update_drag_source_appearance(active: bool) -> void:
	for index in range(_item_container.get_child_count()):
		if queued_entries[index].id != _active_drag_entry_id:
			continue

		var item: AbilitySequenceItemUI = _item_container.get_child(index) as AbilitySequenceItemUI
		if item != null:
			item.set_drag_source_active(active, reorder_animation_duration)
		return


func _capture_item_positions() -> Dictionary[int, Vector2]:
	var positions: Dictionary[int, Vector2] = {}
	for child in _item_container.get_children():
		var item: AbilitySequenceItemUI = child as AbilitySequenceItemUI
		if item == null:
			continue
		positions[item.get_entry_id()] = item.get_hex_global_position()
	return positions


## Containers assign the final layout after the rebuilt children enter the
## scene tree. Matching entries remain visible at their old global positions
## while waiting for pre-draw, then animate into the freshly calculated rows.
## Reading positions on process_frame is too soon and can report the same Y
## position for every Item, which would collapse the sequence into one row.
func _animate_rebuilt_items(previous_positions: Dictionary[int, Vector2]) -> void:
	if previous_positions.is_empty():
		return

	# Hold matching entries instead of hiding them. This removes the blank frame
	# without allowing the rebuilt final positions to flash on screen.
	for child in _item_container.get_children():
		var pending_item: AbilitySequenceItemUI = child as AbilitySequenceItemUI
		if pending_item == null:
			continue
		var entry_id: int = pending_item.get_entry_id()
		if previous_positions.has(entry_id):
			pending_item.hold_layout_transition_at_global_position(
				previous_positions[entry_id]
			)

	await RenderingServer.frame_pre_draw
	if not is_instance_valid(_item_container):
		return

	for child in _item_container.get_children():
		var item: AbilitySequenceItemUI = child as AbilitySequenceItemUI
		if item == null:
			continue

		var entry_id: int = item.get_entry_id()
		if not previous_positions.has(entry_id):
			continue

		var start_position: Vector2 = previous_positions[entry_id]
		item.animate_from_global_position(start_position, layout_animation_duration)


func _find_entry_index(entry_id: int) -> int:
	for index in range(queued_entries.size()):
		if queued_entries[index].id == entry_id:
			return index
	return -1


func _find_item(entry_id: int) -> AbilitySequenceItemUI:
	for child in _item_container.get_children():
		var item: AbilitySequenceItemUI = child as AbilitySequenceItemUI
		if item != null and item.get_entry_id() == entry_id:
			return item
	return null
