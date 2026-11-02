extends Node3D
class_name EnemyAbilityQueueUI

## This Node3D is the world-space head anchor. Its CanvasLayer keeps the
## shared player artwork crisp and the same screen size at any distance.
@export var item_scene: PackedScene = preload("res://UI/AbilitySequenceItemUI.tscn")
@export_range(0.1, 1.0, 0.05) var queue_scale: float = 0.5
@export_range(1.0, 128.0, 1.0) var row_spacing: float = 69.0
@export_range(0.01, 0.75, 0.01, "suffix:s") var animation_duration: float = 0.20
@export var screen_offset: Vector2 = Vector2(-48.0, -8.0)
@export var frame_color: Color = Color(1.0, 0.20, 0.20, 0.85)

var _enemy: Enemy
var _queue: AbilityQueue
var _items: Dictionary[int, AbilitySequenceItemUI] = {}
var _visibility_tween: Tween
var _target_opacity: float = 1.0

@onready var _screen_root: Control = $CanvasLayer/ScreenRoot
@onready var _items_root: Node2D = $CanvasLayer/ScreenRoot/Items


func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_error("EnemyAbilityQueueUI must be a child of an Enemy.")
		set_process(false)
		return
	_queue = _enemy.ability_queue
	add_to_group("enemy_queue_displays")
	_queue.queue_changed.connect(_sync_queue)
	_enemy.died.connect(_on_enemy_died)
	_sync_queue()
	_update_screen_position()


func _process(_delta: float) -> void:
	_update_screen_position()


func _update_screen_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(_enemy) or _enemy.health <= 0:
		_screen_root.hide()
		return
	var screen_position: Vector2 = camera.unproject_position(global_position) + screen_offset
	_screen_root.visible = (
		not camera.is_position_behind(global_position)
		and get_viewport().get_visible_rect().has_point(screen_position)
	)
	_screen_root.position = screen_position
	_items_root.scale = Vector2.ONE * queue_scale


func _sync_queue() -> void:
	var removed_any: bool = false
	var remaining_ids: Array[int] = []
	for entry in _queue.queued_entries:
		remaining_ids.append(entry.id)
	for entry_id in _items.keys():
		if not remaining_ids.has(entry_id):
			var removed: AbilitySequenceItemUI = _items[entry_id]
			_items.erase(entry_id)
			removed.play_removal_animation(animation_duration)
			removed_any = true

	for index in range(_queue.queued_entries.size()):
		var entry: QueuedAbility = _queue.queued_entries[index]
		# Queue front executes first and occupies the fixed bottom slot.
		# After consumption the remaining entries slide down into that slot.
		var depth: int = index
		var align_right: bool = depth % 2 == 1
		var item: AbilitySequenceItemUI = _items.get(entry.id)
		var existing: bool = item != null
		var old_position := Vector2.ZERO
		if existing:
			old_position = item.get_hex_global_position()
		else:
			item = item_scene.instantiate() as AbilitySequenceItemUI
			item.configure(entry.id, entry.ability, entry.target, align_right, null, true)
			item.set_interaction_enabled(false)
			item.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_items_root.add_child(item)
			item.set_frame_color(frame_color)
			_items[entry.id] = item
		# The bottom hex center is (0, 0); all additional rows extend upward.
		item.position = Vector2(-AbilitySequenceItemUI.LEFT_HEX_POSITION.x,
			-AbilitySequenceItemUI.LEFT_HEX_POSITION.y - depth * row_spacing)
		if existing:
			item.configure(entry.id, entry.ability, entry.target, align_right, null)
			item.animate_from_global_position(old_position, animation_duration,
				animation_duration if removed_any else 0.0)


func _on_enemy_died() -> void:
	_screen_root.hide()
	set_process(false)


func get_display_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if not _screen_root.visible or not is_instance_valid(_enemy) or _enemy.health <= 0:
		return polygons
	# Include disappearing blocks until their exit animation completes.
	for child in _items_root.get_children():
		if child is AbilitySequenceItemUI:
			var polygon: PackedVector2Array = child.get_hex_screen_polygon()
			if polygon[0].distance_to(polygon[3]) > 1.0:
				polygons.append(polygon)
	return polygons


func set_display_opacity(opacity: float, duration: float) -> void:
	if is_equal_approx(_target_opacity, opacity):
		return
	_target_opacity = opacity
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(_screen_root, "modulate:a", opacity, duration)


func _exit_tree() -> void:
	if _queue != null and _queue.queue_changed.is_connected(_sync_queue):
		_queue.queue_changed.disconnect(_sync_queue)
	# Visibility manager reparents the screen UI into a shared CanvasLayer.
	if is_instance_valid(_screen_root) and not is_ancestor_of(_screen_root):
		_screen_root.queue_free()
