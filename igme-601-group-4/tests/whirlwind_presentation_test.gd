extends Node

var failures: int = 0
var action_done: bool = false
var action_succeeded: bool = false


func _ready() -> void:
	run.call_deferred()
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func ring_target(radius: int) -> AbilityTarget:
	var target := AbilityTarget.new(Global.TargetingType.ANNULAR)
	target.ring_radius = radius
	target.target_cells = HexGrid.get_ring(Vector2i.ZERO, radius)
	target.is_valid = true
	return target


func run() -> void:
	var arena: Node = load("res://Levels/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var controller: ActionExecutionController = arena.get_node("ActionExecutionController")
	await controller.preparation_started
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	var player: PlayerController = controller.player_actor
	var visual: Node3D = player.presentation_visual
	var ability := load("res://Abilities/Whirlwind.tres").duplicate() as Ability
	check(ability.presentation != null, "Whirlwind must reference its modular presentation")
	var target := ring_target(1)
	var enemies: Array[Node] = arena.get_node("Enemies").get_children()
	enemies[0].movement.set_pos(Vector2i(1, 0))
	enemies[1].movement.set_pos(Vector2i(-1, 0))
	var saved_visual: Transform3D = visual.transform
	var saved_actor: Transform3D = player.global_transform
	var occupancy: Dictionary = HexGrid.occupied_cells.duplicate()
	var route: PackedVector3Array = ability.presentation.build_route(player, visual, target)
	check(route.size() == 9 and route[0] == route[-1] and route[1] == route[-2], "Full ring route must visit six tiles, close the circuit and return home")
	for index in range(1, 7):
		var expected: Vector3 = HexGrid.to_global(HexGrid.hex_to_world(target.target_cells[index - 1]))
		expected.y = visual.global_position.y
		check(route[index].is_equal_approx(expected), "Route must visit selected hex centers in ring order")
	controller.action_finished.connect(record_finished)
	controller.player_queue.add_confirmed_ability(ability, target)
	controller.execute_next(player, controller.player_queue)
	check(not action_done and enemies[0].health == 10, "Whirlwind must suspend without applying immediate damage")
	await get_tree().create_timer(0.12).timeout
	check(not visual.transform.is_equal_approx(saved_visual), "Visual must move during the orbit")
	check(player.global_transform.is_equal_approx(saved_actor), "Actual actor transform must stay fixed")
	check(HexGrid.occupied_cells == occupancy and not player.movement.is_moving, "Orbit must not change occupancy or run CharacterMovement")
	check(enemies[0].health == 10 and enemies[1].health == 10, "No enemy damage before the model returns")
	if "--capture-whirlwind" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../whirlwind-mid-orbit.png")
	if not action_done:
		await controller.action_finished
	check(action_succeeded and visual.transform.is_equal_approx(saved_visual), "Successful playback must restore position, rotation and scale")
	check(enemies[0].health == 7 and enemies[1].health == 7, "Return must apply ring damage once")
	check(not controller.player_queue.has_entries(), "Queue consumption must wait for presentation and damage")

	# Consecutive use and an outer ring use the same shared resource safely.
	ability.range = 2
	check(await player.execute_ability(ability, ring_target(2)), "Second playback on a different radius must complete")
	check(visual.transform.is_equal_approx(saved_visual), "Repeated playback must not accumulate visual drift")
	player.movement.set_pos(Vector2i(4, 0))
	var edge_route: PackedVector3Array = ability.presentation.build_route(player, visual, target)
	check(edge_route.size() == 5, "Clipped corner ring must visit only three valid tiles and return")
	check(await player.execute_ability(ability, target), "Clipped boundary ring must still animate and finish")
	check(visual.transform.is_equal_approx(saved_visual), "Boundary playback must restore the visual")
	player.movement.set_pos(Vector2i.ZERO)
	var instant := ability.duplicate() as Ability
	instant.presentation = null
	instant.damage = 1
	action_done = false
	controller.player_queue.add_confirmed_ability(instant, target)
	controller.execute_next(player, controller.player_queue)
	check(action_done and action_succeeded, "Clearing the optional presentation must restore immediate attack behavior")
	check(visual.transform.is_equal_approx(saved_visual), "Disabled presentation must not change the model")

	# Death midway through the animation cancels damage and restores the model.
	action_done = false
	controller.player_queue.add_confirmed_ability(ability, target)
	controller.execute_next(player, controller.player_queue)
	await get_tree().create_timer(0.10).timeout
	var health_before: int = enemies[0].health
	player.damage(player.max_health)
	check(action_done and not action_succeeded, "Death must release the waiting action as cancelled")
	check(visual.transform.is_equal_approx(saved_visual), "Cancellation must restore the exact original transform")
	check(enemies[0].health == health_before, "Cancelled presentation must not apply damage")
	await get_tree().process_frame
	for child in player.get_children():
		check(child.get_script() != load("res://Abilities/Presentation/presentation_motion.gd"), "Temporary playback nodes must be cleaned up")
	print("WHIRLWIND_PRESENTATION_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)


func record_finished(_actor: Node, _entry: QueuedAbility, succeeded: bool) -> void:
	action_done = true
	action_succeeded = succeeded
