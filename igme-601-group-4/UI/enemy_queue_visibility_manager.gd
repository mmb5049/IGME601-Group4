extends CanvasLayer

@export_range(0.0, 1.0, 0.05) var faded_opacity: float = 0.25
@export_range(0.0, 0.5, 0.01, "suffix:s") var fade_duration: float = 0.12

var _hovered_queue: EnemyAbilityQueueUI
var _active_queue: EnemyAbilityQueueUI
var _preview_entry: QueuedAbility
var _mouse_inside := true
@onready var _game_over := get_parent().get_node_or_null("%GameOver") as CanvasLayer
@onready var _controller := get_parent().get_node_or_null("ActionExecutionController") as ActionExecutionController

func has_icon_hover() -> bool:
	return is_instance_valid(_active_queue)



func _ready() -> void:
	# Run after the overhead followers have updated their screen positions.
	process_priority = 100
	get_window().mouse_entered.connect(func(): _mouse_inside = true)
	get_window().mouse_exited.connect(func():
		_mouse_inside = false
		_update_icon_hover(null, -1, Vector2.INF)
	)


func _process(_delta: float) -> void:
	update_visibility(CRTOverlay.get_content_mouse_position(get_viewport()))


func update_visibility(mouse_position: Vector2) -> void:
	var queues: Array[EnemyAbilityQueueUI] = []
	var polygons: Dictionary = {}
	var model_hover_queue: EnemyAbilityQueueUI
	for node in get_tree().get_nodes_in_group("enemy_queue_displays"):
		var queue := node as EnemyAbilityQueueUI
		if queue == null or not get_parent().is_ancestor_of(queue):
			continue
		# All roots share a canvas so z_index sorts across different enemies.
		if queue._screen_root.get_parent() != self:
			queue._screen_root.reparent(self, true)
		var shapes: Array[PackedVector2Array] = queue.get_display_polygons()
		if not shapes.is_empty():
			queues.append(queue)
			polygons[queue] = shapes
			if queue._enemy.is_model_hovered:
				model_hover_queue = queue
	queues.sort_custom(_is_above)

	# Keep the hovered (frontmost) queue stable while the pointer stays on it.
	if not is_instance_valid(_hovered_queue) or not queues.has(_hovered_queue):
		_hovered_queue = null
	elif not _contains_point(polygons[_hovered_queue], mouse_position):
		_hovered_queue = null
	if _hovered_queue == null:
		for index in range(queues.size() - 1, -1, -1):
			if _contains_point(polygons[queues[index]], mouse_position):
				_hovered_queue = queues[index]
				break

	var index_at_mouse := -1
	var viewport := get_viewport()
	if is_instance_valid(_hovered_queue) and visible and _mouse_inside and (not _game_over or not _game_over.visible):
		if viewport.gui_get_hovered_control() == null and not viewport.gui_is_dragging():
			index_at_mouse = _hovered_queue.entry_index_at(mouse_position)
	_update_icon_hover(_hovered_queue if index_at_mouse >= 0 else null, index_at_mouse, mouse_position)
	var foreground := _active_queue if _active_queue else model_hover_queue
	if not foreground:
		foreground = _hovered_queue
	for index in range(queues.size()):
		var queue: EnemyAbilityQueueUI = queues[index]
		var faded: bool = false
		if queue != foreground:
			if foreground != null and _overlaps(polygons[queue], polygons[foreground]):
				faded = true
			else:
				for lower_index in range(index + 1, queues.size()):
					if queues[lower_index] != foreground and _overlaps(polygons[queue], polygons[queues[lower_index]]):
						faded = true
						break
		queue.set_display_opacity(faded_opacity if faded else 1.0, fade_duration)
		queue._screen_root.z_index = queues.size() if queue == foreground else index


func _update_icon_hover(queue: EnemyAbilityQueueUI, index: int, point: Vector2) -> void:
	if queue != _active_queue:
		if is_instance_valid(_active_queue):
			_active_queue.set_hover_point(Vector2.INF)
		_active_queue = queue
		if queue:
			queue.set_hover_point(point)

	var entry: QueuedAbility
	if queue and _controller and _controller.current_phase == ActionExecutionController.TurnPhase.PREPARATION:
		if _controller.player_actor.current_mode != PlayerController.PlayerMode.ACTING:
			entry = queue._enemy.ability_queue.queue[index]
	if entry and (entry != _preview_entry or _controller.preview_actor != queue._enemy):
		_controller.preview_queue(index, queue._enemy)
	elif not entry and _preview_entry and _controller.preview_actor != _controller.player_actor:
		if _controller.current_phase == ActionExecutionController.TurnPhase.PREPARATION:
			var player := _controller.player_actor
			player.clear_preview()
			if player.current_mode == PlayerController.PlayerMode.TARGETING:
				_controller.preview_queue(player.ability_queue.size())
				player.update_ability_preview(player.hologram.movement.current_cell)
	_preview_entry = entry


func _is_above(a: EnemyAbilityQueueUI, b: EnemyAbilityQueueUI) -> bool:
	# Arena lies on X/Z. Smaller transform Z means farther up the board.
	# Neither camera projection nor queue height participates in this priority.
	if not is_equal_approx(a._enemy.global_position.z, b._enemy.global_position.z):
		return a._enemy.global_position.z < b._enemy.global_position.z
	if a._enemy.action_number != b._enemy.action_number:
		return a._enemy.action_number < b._enemy.action_number
	return a.get_instance_id() < b.get_instance_id()


func _contains_point(shapes: Array, point: Vector2) -> bool:
	for polygon in shapes:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _overlaps(first: Array, second: Array) -> bool:
	for a in first:
		for b in second:
			if not Geometry2D.intersect_polygons(a, b).is_empty():
				return true
	return false
