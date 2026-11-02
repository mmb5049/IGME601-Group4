extends Node

var failures: int = 0


func _ready() -> void:
	run.call_deferred()
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var arena: Node = load("res://Levels/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var controller: ActionExecutionController = arena.get_node("ActionExecutionController")
	await controller.preparation_started
	await get_tree().create_timer(0.3).timeout
	for actor in controller.action_order:
		var number_ui: Node3D = actor.get_node("ActionNumberUI")
		var label: Label = number_ui.get_node("CanvasLayer/Number")
		check(label.text == str(actor.action_number), "Head number must match assigned turn order")
		var projected: Vector2 = get_viewport().get_camera_3d().unproject_position(number_ui.global_position)
		check((label.position + label.size * 0.5).distance_to(projected) < 0.1, "Action number must be centered directly above the actor")
		check(label.visible and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Action number must be visible and non-interactive")
	var enemy: Enemy = controller.action_order[1]
	var ui: EnemyAbilityQueueUI = enemy.get_node("EnemyAbilityQueueUI")
	var number_label: Label = enemy.get_node("ActionNumberUI/CanvasLayer/Number")
	var assigned_number: int = enemy.action_number
	enemy.action_number = 99
	check(number_label.text == "99", "Number changes must refresh immediately")
	enemy.action_number = assigned_number
	check(ui._items.size() == enemy.ability_queue.queued_entries.size(), "UI must show every planned entry")
	var original: QueuedAbility = enemy.ability_queue.peek_front_entry()
	for item in ui._items.values():
		check(not item._interaction_enabled and item.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Enemy entries must pass mouse input through")
		if item._ability.targeting_type == Global.TargetingType.DIRECTION:
			check(item._direction_edges._active_direction_index == HexGrid.DIRECTIONS.find(item._target.direction), "UI direction must match the stored ability target")
		else:
			check(item._direction_edges._active_direction_index == -1, "Ring attacks must not show a movement direction")
		check(item._hex_display.get_node("VisualContent/HexFrame").self_modulate == ui.frame_color, "Enemy frame must be red")
	check(ui.screen_offset.x < 0 and ui.screen_offset.y < 0, "Enemy queue must sit above and left of its head anchor")
	var camera := get_viewport().get_camera_3d()
	var bottom_id: int = original.id
	var bottom: AbilitySequenceItemUI = ui._items[bottom_id]
	var anchor: Vector2 = camera.unproject_position(ui.global_position) + ui.screen_offset
	check(bottom.get_hex_global_position().distance_to(anchor) < 0.1, "Bottom hex must be centered on the head anchor")
	check(bottom._hex_display.global_scale.is_equal_approx(Vector2.ONE * 0.36), "Enemy hex must be half the player queue size")
	var removed: AbilitySequenceItemUI = ui._items[original.id]
	var next: AbilitySequenceItemUI = ui._items[enemy.ability_queue.queued_entries[1].id]
	var next_position: Vector2 = next.get_hex_global_position()
	enemy.ability_queue.consume_entry(original.id)
	check(not ui._items.has(original.id) and is_instance_valid(removed), "Consumed entry must play an exit animation before freeing")
	await get_tree().create_timer(0.08).timeout
	check(next.get_hex_global_position().distance_to(next_position) < 0.1, "Remaining queue must wait for the removal animation before shifting")
	await get_tree().create_timer(0.4).timeout
	check(not is_instance_valid(removed), "Exit animation must clean up the consumed item")
	check(next.get_hex_global_position().distance_to(anchor) < 0.1, "Next action must slide down into the fixed bottom slot")
	for count in [1, 2, 6]:
		enemy.ability_queue.clear_queue()
		for index in range(count):
			enemy.ability_queue.add_ability(original.ability, original.target)
		await get_tree().create_timer(0.25).timeout
		check(ui._items.size() == count, "UI count must match queue after regeneration")
		bottom = ui._items[enemy.ability_queue.peek_front_entry().id]
		check(bottom.get_hex_global_position().distance_to(anchor) < 0.1, "Bottom anchor must be independent of queue length")
		var top: AbilitySequenceItemUI = ui._items[enemy.ability_queue.queued_entries.back().id]
		check(is_equal_approx(top.get_hex_global_position().y, anchor.y - (count - 1) * ui.row_spacing * ui.queue_scale), "Queue must extend upward in execution order")

	# Moving the actor updates the screen position, including after resizing.
	enemy.movement.set_pos(Vector2i(0, 3))
	await get_tree().process_frame
	await get_tree().process_frame
	anchor = camera.unproject_position(ui.global_position) + ui.screen_offset
	check(bottom.get_hex_global_position().distance_to(anchor) < 0.1, "Queue must follow enemy movement")
	var anchor_position: Vector3 = ui.global_position
	ui.global_position = camera.global_position + camera.global_basis.z * 2.0
	ui._update_screen_position()
	check(not ui._screen_root.visible, "Queue behind the camera must be hidden")
	ui.global_position = anchor_position
	ui._update_screen_position()
	check(ui._screen_root.visible, "Queue must reappear when its anchor returns onscreen")
	enemy.ability_queue.clear_queue()
	await get_tree().create_timer(0.25).timeout
	check(ui._items_root.get_child_count() == 0, "Empty queue must clean up all visuals")
	enemy.prepare_turn(controller.player_actor)
	await get_tree().create_timer(0.3).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../enemy-queue-preview.png")
	enemy.die()
	check(not ui._screen_root.visible, "Death must immediately hide the queue")
	check(not number_label.visible, "Death must immediately hide the action number")
	await get_tree().process_frame
	check(not is_instance_valid(ui), "Enemy death must free its CanvasLayer and queue")
	print("ENEMY_UI_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)
