extends Node

var failures: int = 0
var action_done: bool = false
var action_succeeded: bool = false
var completion_count: int = 0
var controller: ActionExecutionController


func _ready() -> void:
	run.call_deferred()
	get_tree().create_timer(20.0).timeout.connect(func():
		push_error("Blocked movement test timed out")
		get_tree().quit(1)
	)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func directional_target(direction: Vector2i) -> AbilityTarget:
	var target := AbilityTarget.new(Global.TargetingType.DIRECTION)
	target.direction = direction
	target.is_valid = true
	return target


func record_finished(_actor: Node, _entry: QueuedAbility, succeeded: bool) -> void:
	action_done = true
	action_succeeded = succeeded


func record_movement_finished(_sender: Signal) -> void:
	completion_count += 1


## Observe the full queued action, including each visible phase and grid safety.
func check_blocked_action(actor: Node3D, ability: Ability, direction: Vector2i) -> void:
	var queue := AbilityQueue.new()
	queue.add_ability(ability, directional_target(direction))
	var origin: Vector3 = actor.global_position
	var actor_basis: Basis = actor.global_basis
	var cell: Vector2i = actor.movement.current_cell
	var occupancy: Dictionary = HexGrid.occupied_cells.duplicate()
	var forward: Vector3 = HexGrid.hex_to_world(direction).normalized()
	var sideways: Vector3 = forward.cross(Vector3.UP)
	var saw_advance: bool = false
	var saw_return: bool = false
	var saw_shake: bool = false
	var elapsed: float = 0.0
	var completions_before: int = completion_count
	action_done = false
	controller.execute_next(actor, queue)
	check(not action_done and actor.movement.is_moving, "Blocked action must suspend the queue")
	while not action_done:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var offset: Vector3 = actor.global_position - origin
		if offset.dot(forward) > 0.05:
			saw_advance = true
		if saw_advance and absf(offset.dot(forward)) < 0.001:
			saw_return = true
		if saw_return and absf(offset.dot(sideways)) > 0.005:
			saw_shake = true
		check(is_equal_approx(actor.global_position.y, origin.y), "Feedback must stay on the horizontal plane")
		check(actor.movement.current_cell == cell and actor.movement.target_cell == cell, "Feedback must not change logical cells")
		check(HexGrid.occupied_cells == occupancy, "Feedback must preserve every grid occupant")
		check(actor.movement.facing_visual.global_basis.z.normalized().dot(forward) > 0.999, "Body must keep facing the attempted direction during return and shake")
		check(actor.global_basis.is_equal_approx(actor_basis), "Body facing must not rotate the actor or overhead UI")
		if not action_done:
			check(queue.has_entries() and actor.movement.is_moving, "Queue entry must remain active throughout feedback")
	check(saw_advance and saw_return and saw_shake, "Feedback must advance, return, then shake sideways")
	check(elapsed >= 0.64 and elapsed < 1.0, "Completion must wait for advance, quick return and 0.5 seconds of shaking")
	check(not action_succeeded and not queue.has_entries(), "Blocked movement must report failure and consume its entry after feedback")
	check(actor.global_position == origin and not actor.movement.is_moving, "Completion must restore the exact position and movement state")
	check(completion_count == completions_before + 1, "Feedback must emit movement completion exactly once")


func check_legal_facing(actor: Node3D, ability: Ability, direction: Vector2i) -> void:
	actor.movement.set_pos(Vector2i.ZERO)
	var actor_basis: Basis = actor.global_basis
	var visual: Node3D = actor.movement.facing_visual
	var visual_position: Vector3 = visual.position
	var visual_scale: Vector3 = visual.scale
	var forward: Vector3 = HexGrid.hex_to_world(direction).normalized()
	var queue := AbilityQueue.new()
	queue.add_ability(ability, directional_target(direction))
	action_done = false
	controller.execute_next(actor, queue)
	while not action_done:
		check(visual.global_basis.z.normalized().dot(forward) > 0.999, "Body must face travel direction throughout legal movement")
		await get_tree().physics_frame
	await get_tree().create_timer(0.05).timeout
	check(action_succeeded and actor.movement.current_cell == direction, "Facing must preserve normal movement completion")
	check(visual.global_basis.z.normalized().dot(forward) > 0.999, "Body must retain its last facing after stopping and animation updates")
	check(actor.global_basis.is_equal_approx(actor_basis), "Legal movement must rotate only the body")
	check(visual.position.is_equal_approx(visual_position) and visual.scale.is_equal_approx(visual_scale), "Turning must preserve visual position and scale")


func run() -> void:
	var arena: Node = load("res://Levels/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	controller = arena.get_node("ActionExecutionController")
	await controller.preparation_started
	controller.action_finished.connect(record_finished)
	var player: PlayerController = controller.player_actor
	var enemies: Array[Node] = arena.get_node("Enemies").get_children()
	# Isolate the paths from the arena's random spawn positions.
	HexGrid.occupied_cells.clear()
	for index in range(enemies.size()):
		enemies[index].movement.set_pos(Vector2i(-4, index))
	player.movement.set_pos(Vector2i.ZERO)
	var blocker: Enemy = enemies[0]
	blocker.movement.set_pos(Vector2i(1, 0))
	player.movement.done_moving.connect(record_movement_finished)
	blocker.movement.done_moving.connect(record_movement_finished)

	await check_blocked_action(player, player.get_ability("Move"), Vector2i(1, 0))
	await check_blocked_action(player, player.get_ability("Dash"), Vector2i(1, 0))
	await check_blocked_action(blocker, blocker.move_ability, Vector2i(-1, 0))
	# Diagonal motion and map edges use the same horizontal feedback.
	player.movement.set_pos(Vector2i(0, 4))
	await check_blocked_action(player, player.get_ability("Move"), Vector2i(0, 1))

	# Repeated failures must not interfere with subsequent legal movement.
	player.movement.set_pos(Vector2i.ZERO)
	blocker.movement.set_pos(Vector2i(2, 0))
	check(await player.execute_ability(player.get_ability("Dash"), directional_target(Vector2i(1, 0))), "Partially blocked Dash must still reach the last free tile")
	check(player.movement.current_cell == Vector2i(1, 0), "Dash must stop before the obstacle")
	check(await player.execute_ability(player.get_ability("Move"), directional_target(Vector2i(0, 1))), "Legal Move must still complete after feedback")
	check(player.movement.current_cell == Vector2i(1, 1), "Legal Move must update its cell")
	check(not await player.movement.execute_directional_move(Vector2i.ZERO, 1), "Invalid direction must remain an immediate rejection")
	# Both bodies must face all six hex directions, including animated players.
	blocker.movement.set_pos(Vector2i(4, 0))
	for direction: Vector2i in HexGrid.DIRECTIONS:
		await check_legal_facing(player, player.get_ability("Move"), direction)
	player.movement.set_pos(Vector2i(4, -1))
	for direction: Vector2i in HexGrid.DIRECTIONS:
		await check_legal_facing(blocker, blocker.move_ability, direction)

	# Death must restore position and release the suspended queue exactly once.
	player.movement.set_pos(Vector2i.ZERO)
	blocker.movement.set_pos(Vector2i(1, 0))
	var queue := AbilityQueue.new()
	queue.add_ability(player.get_ability("Move"), directional_target(Vector2i(1, 0)))
	var origin: Vector3 = player.global_position
	var completions_before: int = completion_count
	action_done = false
	controller.execute_next(player, queue)
	await get_tree().create_timer(0.05).timeout
	player.damage(player.max_health)
	check(action_done and not action_succeeded and not queue.has_entries(), "Death must release the pending blocked action")
	check(player.global_position == origin and not player.movement.is_moving, "Death must restore position and clear movement state")
	await get_tree().create_timer(0.7).timeout
	check(completion_count == completions_before + 1 and player.global_position == origin, "Cancelled feedback must not finish again or leave a running tween")

	print("BLOCKED_MOVEMENT_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)
