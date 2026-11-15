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
	var manager: Node = arena.get_node("EnemyQueueVisibilityManager")
	manager.set_process(false)
	var displays: Array[EnemyAbilityQueueUI] = []
	for actor in controller.action_order:
		if actor is Enemy:
			var ui: EnemyAbilityQueueUI = actor.get_node("EnemyAbilityQueueUI")
			ui.set_process(false)
			ui._screen_root.hide()
			displays.append(ui)
	var upper: EnemyAbilityQueueUI = displays[0]
	var lower: EnemyAbilityQueueUI = displays[1]
	var third: EnemyAbilityQueueUI = displays[2]
	for ui in [upper, lower, third]:
		ui._queue.clear_queue()
		var target := AbilityTarget.new(Global.TargetingType.DIRECTION)
		target.direction = Vector2i(1, 0)
		target.is_valid = true
		ui._queue.add_ability(ui._enemy.move_ability, target)
	await get_tree().create_timer(0.3).timeout
	upper._enemy.global_position.z = -2.0
	lower._enemy.global_position.z = 2.0
	third._enemy.global_position.z = 4.0
	upper._screen_root.show()
	lower._screen_root.show()
	upper._screen_root.position = Vector2(500, 400)
	lower._screen_root.position = Vector2(520, 400)
	manager.update_visibility(Vector2.ZERO)
	await get_tree().create_timer(0.15).timeout
	check(is_equal_approx(upper._screen_root.modulate.a, 0.25), "Upper world-Z queue must fade on overlap")
	check(is_equal_approx(lower._screen_root.modulate.a, 1.0), "Lower world-Z queue must remain opaque")
	check(upper._screen_root.z_index < lower._screen_root.z_index, "Lower queue must draw in front")
	check(upper._screen_root.get_parent() == lower._screen_root.get_parent(), "Queues must share a canvas for sorting")
	var label: Label = upper._enemy.get_node("ActionNumberUI/CanvasLayer/Number")
	check(is_equal_approx(label.modulate.a, 1.0), "Action number must not fade with queue")
	await capture("queue-overlap-default.png")

	# The exposed left side selects the faded upper queue, then stays selected
	# when moving into the overlap. No Control consumes input for hovering.
	manager.update_visibility(Vector2(488, 400))
	await get_tree().create_timer(0.15).timeout
	check(upper._target_opacity == 1.0 and lower._target_opacity == 0.25, "Hover must override world-Z priority")
	check(upper._screen_root.z_index > lower._screen_root.z_index, "Hovered queue must draw in front")
	await capture("queue-overlap-hover.png")
	manager.update_visibility(Vector2(510, 400))
	check(manager._hovered_queue == upper, "Hover must not oscillate inside an overlap")
	manager.update_visibility(Vector2(536, 400))
	check(manager._hovered_queue == lower, "Pointer can select another queue on its exposed side")
	manager.update_visibility(Vector2.ZERO)
	check(upper._target_opacity == 0.25 and lower._target_opacity == 1.0, "Leaving queues restores default priority")

	# Invert world Z while leaving screen geometry untouched: priority must
	# depend only on the enemy transform, not the camera or UI position.
	upper._enemy.global_position.z = 5.0
	manager.update_visibility(Vector2.ZERO)
	check(upper._target_opacity == 1.0 and lower._target_opacity == 0.25, "Transform Z change must immediately reverse priority")
	lower._screen_root.position.x = 800
	manager.update_visibility(Vector2.ZERO)
	check(upper._target_opacity == 1.0 and lower._target_opacity == 1.0, "Separated queues must both recover")

	# Three overlapping queues: hovering one must fade every direct neighbor.
	lower._screen_root.position.x = 520
	third._screen_root.position = Vector2(535, 400)
	third._screen_root.show()
	manager.update_visibility(Vector2(488, 400))
	check(upper._target_opacity == 1.0 and lower._target_opacity == 0.25 and third._target_opacity == 0.25, "Hover must fade multiple overlapping queues")
	third._screen_root.position.x = 560
	manager.update_visibility(Vector2(488, 400))
	check(third._target_opacity == 1.0, "A queue outside hovered geometry must keep default visibility")
	var detached_root: Control = upper._screen_root
	upper._enemy.die()
	manager.update_visibility(Vector2.ZERO)
	check(manager._hovered_queue == null, "Dying hovered enemy must release hover")
	await get_tree().process_frame
	manager.update_visibility(Vector2.ZERO)
	check(not is_instance_valid(upper), "Reparented queue UI must be freed with enemy")
	check(not is_instance_valid(detached_root), "Death must free the reparented screen root too")

	# Disappearing blocks remain in overlap geometry until their animation
	# finishes, then empty queues must stop affecting other queues.
	third._screen_root.hide()
	lower._queue.clear_queue()
	manager.update_visibility(Vector2.ZERO)
	check(not lower.get_display_polygons().is_empty(), "Exit animation must still participate in overlap geometry")
	await get_tree().create_timer(0.25).timeout
	check(lower.get_display_polygons().is_empty(), "Consumed queue must stop participating after animation")
	print("QUEUE_OVERLAP_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)


func capture(filename: String) -> void:
	if "--capture-overlap" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../" + filename)
