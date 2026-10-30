extends Node

var failures: int = 0
var player: PlayerController
var enemies: Array[Node]
var action_done: bool = false
var action_succeeded: bool = false


func _ready() -> void:
	run.call_deferred()
	get_tree().create_timer(25.0).timeout.connect(func(): get_tree().quit(1))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func place(player_cell: Vector2i, enemy_cells: Array[Vector2i]) -> void:
	player.movement.set_pos(player_cell)
	for index in range(enemies.size()):
		enemies[index].movement.set_pos(enemy_cells[index])
	# set_pos clears previous cells; rebuild occupancy once to allow swaps.
	HexGrid.occupied_cells.clear()
	HexGrid.set_occupied(player_cell, player)
	for enemy in enemies:
		HexGrid.set_occupied(enemy.movement.current_cell, enemy)


func run() -> void:
	var arena: Node = load("res://Levels/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var controller: ActionExecutionController = arena.get_node("ActionExecutionController")
	await controller.preparation_started
	await get_tree().create_timer(0.3).timeout
	player = controller.player_actor
	enemies = arena.get_node("Enemies").get_children()
	var attacker: Enemy = enemies[0]
	attacker.minimum_actions = 3
	attacker.maximum_actions = 3
	var parking: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-4, 0), Vector2i(0, -4), Vector2i(-2, 4)]
	place(Vector2i(1, 0), parking)
	attacker.prepare_turn(player)
	for entry in attacker.ability_queue.queued_entries:
		check(entry.ability == attacker.attack_ability and entry.target.ring_radius == 1, "In-range enemy must plan Whirlwind instead of moving")
	attacker.minimum_actions = 2
	attacker.maximum_actions = 2
	place(Vector2i(2, 0), parking)
	attacker.prepare_turn(player)
	check(attacker.ability_queue.queued_entries[0].ability == attacker.move_ability and attacker.ability_queue.queued_entries[1].ability == attacker.attack_ability, "One move into range must be followed by Whirlwind")
	attacker.minimum_actions = 3
	attacker.maximum_actions = 3
	place(Vector2i(3, 0), parking)
	attacker.prepare_turn(player)
	check(attacker.ability_queue.queued_entries[0].ability == attacker.move_ability and attacker.ability_queue.queued_entries[1].ability == attacker.move_ability and attacker.ability_queue.queued_entries[2].ability == attacker.attack_ability, "Two predicted moves into range must allow a third-slot Whirlwind")
	place(Vector2i(4, 0), parking)
	attacker.prepare_turn(player)
	for entry in attacker.ability_queue.queued_entries:
		check(entry.ability == attacker.move_ability, "A turn without enough slots to reach attack range must only move")
	place(Vector2i(2, 0), [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, -4), Vector2i(-2, 4)])
	attacker.prepare_turn(player)
	var predicted: Vector2i = attacker.movement.current_cell
	for entry in attacker.ability_queue.queued_entries:
		if entry.ability == attacker.move_ability:
			var destination: Vector2i = attacker._predict_move(predicted, entry.target.direction)
			check(destination != Vector2i(1, 0), "Prediction must avoid occupied destinations")
			predicted = destination
	check(attacker.ability_queue.queued_entries.back().ability == attacker.attack_ability and HexGrid.hex_distance(predicted, player.movement.current_cell) == 1, "Planning must find a legal approach around a blocker")

	# Run the real turn scheduler with a Move -> Whirlwind enemy plan.
	place(Vector2i(2, 0), parking)
	attacker.minimum_actions = 2
	attacker.maximum_actions = 2
	attacker.prepare_turn(player)
	for other in enemies:
		if other != attacker:
			other.ability_queue.clear_queue()
	controller.player_queue.add_ability(player.get_ability("Wait"))
	controller._on_execute_requested()
	await controller.preparation_started
	check(player.current_health == 97 and attacker.movement.current_cell == Vector2i(1, 0), "Real scheduler must complete a planned approach followed by player damage")
	check(controller.current_phase == ActionExecutionController.TurnPhase.PREPARATION, "Enemy attack turn must return to preparation")
	player.heal(player.max_health)
	attacker.minimum_actions = 3
	attacker.maximum_actions = 3

	place(Vector2i(1, 0), [Vector2i.ZERO, Vector2i(0, 1), Vector2i(2, 0), Vector2i(-4, 0)])
	attacker.prepare_turn(player)
	var visual: Transform3D = attacker.mesh.transform
	var actor_transform: Transform3D = attacker.global_transform
	var occupancy: Dictionary = HexGrid.occupied_cells.duplicate()
	controller.action_finished.connect(record_finished)
	controller.execute_next(attacker, attacker.ability_queue)
	await get_tree().create_timer(0.12).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	check(not action_done and player.current_health == 100 and enemies[1].health == 10, "Enemy animation must delay player and friendly-fire damage")
	check(not attacker.mesh.transform.is_equal_approx(visual), "Enemy must use the same Whirlwind orbit presentation")
	check(attacker.global_transform.is_equal_approx(actor_transform) and HexGrid.occupied_cells == occupancy, "Enemy presentation must not change logical occupancy")
	if not action_done:
		await controller.action_finished
	check(action_succeeded and player.current_health == 97, "Whirlwind must call the player damage interface once")
	check(enemies[1].health == 7 and enemies[2].health == 10 and attacker.health == 10, "Whirlwind must damage other enemies in the ring, exclude outsiders and never hit itself")
	check(attacker.mesh.transform.is_equal_approx(visual), "Enemy model must return before damage resolves")
	check(attacker.ability_queue.queued_entries.size() == 2, "Whole attack must consume one queue slot")

	# Plans do not chase the player during execution: moving out can dodge.
	action_done = false
	controller.execute_next(attacker, attacker.ability_queue)
	await get_tree().create_timer(0.10).timeout
	player.movement.set_pos(Vector2i(3, 0))
	if not action_done:
		await controller.action_finished
	check(player.current_health == 97 and enemies[1].health == 4, "Execution must use actual occupants, including continued friendly fire")

	# Friendly fire can kill another scheduled enemy and release its cell.
	enemies[1].health = 3
	check(await controller.execute_next(attacker, attacker.ability_queue), "Lethal friendly fire must finish normally")
	check(enemies[1].is_queued_for_deletion() and not HexGrid.is_occupied(Vector2i(0, 1)), "Friendly-fire death must release occupancy")
	await get_tree().process_frame

	# Killing the attacker during its own presentation cancels the attack.
	player.movement.set_pos(Vector2i(1, 0))
	attacker.prepare_turn(player)
	action_done = false
	controller.execute_next(attacker, attacker.ability_queue)
	await get_tree().create_timer(0.10).timeout
	attacker.damage(100)
	check(action_done and not action_succeeded and player.current_health == 97, "Attacker death must cancel presentation without dealing damage")
	check(attacker.mesh.transform.is_equal_approx(visual), "Cancelled enemy presentation must restore the mesh")
	await get_tree().process_frame
	await get_tree().process_frame
	print("ENEMY_ATTACK_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)


func record_finished(_actor: Node, _entry: QueuedAbility, succeeded: bool) -> void:
	action_done = true
	action_succeeded = succeeded
