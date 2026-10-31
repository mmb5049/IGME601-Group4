extends Node

var failures: int = 0
var observed: Array[int] = []
var controller: ActionExecutionController
var arena: Node


func _ready() -> void:
	run.call_deferred()
	# A stalled movement coroutine should fail the test instead of hanging CI.
	get_tree().create_timer(20.0).timeout.connect(func():
		push_error("Turn test timed out")
		get_tree().quit(1)
	)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	arena = load("res://Levels/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	controller = arena.get_node("ActionExecutionController")
	controller.between_actions_delay = 0.01
	await controller.preparation_started
	check(controller.turn_number == 1, "Initial preparation must happen once")
	check(controller.action_order.size() == 5, "All four spawned enemies must be planned")
	var initial_entries: Array[QueuedAbility] = []
	for index in range(controller.action_order.size()):
		var actor: Node = controller.action_order[index]
		check(actor.action_number == index + 1, "Action numbers must be unique and ordered")
		if actor is Enemy:
			check(actor.ability_queue.queued_entries.size() in [2, 3], "Enemy must receive 2-3 actions")
			var first: QueuedAbility = actor.ability_queue.peek_front_entry()
			initial_entries.append(first)
			for entry in actor.ability_queue.queued_entries:
				check(entry.ability == actor.move_ability or entry.ability == actor.attack_ability, "Plan must contain configured Move or Whirlwind resources")
	controller.begin_preparation()
	check(controller.turn_number == 1, "Repeated preparation request must not reroll plans")
	check((controller.action_order[1] as Enemy).ability_queue.peek_front_entry() == initial_entries[0], "Preparation must preserve queue entries")

	# Unequal queues exercise multiple passes and skipping exhausted actors.
	# Keep this scheduler regression independent of attack deaths/AI choices.
	for actor in controller.action_order:
		if actor is Enemy:
			actor.attack_ability = null
			actor.prepare_turn(controller.player_actor)
	var lengths: Array[int] = [2, 3, 2, 3]
	for index in range(1, 5):
		var enemy: Enemy = controller.action_order[index]
		while enemy.ability_queue.queued_entries.size() > lengths[index - 1]:
			enemy.ability_queue.consume_entry(enemy.ability_queue.peek_front_entry().id)
		while enemy.ability_queue.queued_entries.size() < lengths[index - 1]:
			var entry: QueuedAbility = enemy.ability_queue.peek_front_entry()
			enemy.ability_queue.add_ability(entry.ability, entry.target)
	controller.player_queue.add_ability(controller.player_actor.get_ability("Wait"))
	controller.player_queue.add_ability(controller.player_actor.get_ability("Wait"))
	controller.action_started.connect(record_action)
	controller._on_execute_requested()
	controller._on_execute_requested()
	await controller.preparation_started
	check(observed == [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 3, 5], "Must execute one entry per actor, in number order")
	check(controller.turn_number == 2, "Completion must enter the next preparation exactly once")
	for actor in controller.action_order:
		var label: Label = actor.get_node("ActionNumberUI/CanvasLayer/Number")
		check(label.text == str(actor.action_number), "Head numbers must refresh after each preparation")
	check(controller.player_queue._interaction_enabled, "Preparation must unlock player queue")
	check(controller.player_actor.current_mode == PlayerController.PlayerMode.NONE, "Player must return to planning mode")
	check(controller.player_actor.current_mana == controller.player_actor.max_mana, "Mana must refill after execution")
	for actor in controller.action_order:
		if actor is Enemy:
			check(actor.ability_queue.queued_entries.size() in [2, 3], "New turn must replace consumed enemy queues")

	# Empty player plan must still allow enemies to act. Free one scheduled
	# enemy to exercise stale references in the turn snapshot.
	observed.clear()
	var victim: Enemy = controller.action_order[1]
	victim.die()
	await get_tree().process_frame
	controller._on_execute_requested()
	await controller.preparation_started
	check(not observed.has(1) and not observed.has(2), "Empty player queue and freed enemy must be skipped")
	check(observed.size() >= 6, "Surviving enemies must finish their queues")
	check(controller.action_order.size() == 4, "Next preparation must only number surviving actors")

	# A blocked Move consumes a queue step without overwriting occupancy.
	var enemy: Enemy = controller.action_order[1]
	var cell: Vector2i = enemy.movement.current_cell
	var target := AbilityTarget.new(Global.TargetingType.DIRECTION)
	target.direction = Vector2i(1, 0)
	target.is_valid = true
	var destination: Vector2i = cell + target.direction
	if HexGrid.is_valid_cell(destination):
		HexGrid.set_occupied(destination, controller.player_actor)
	var entry := QueuedAbility.new(999, enemy.move_ability, target)
	check(not await enemy.execute_queued_ability(entry), "Occupied or out-of-bounds Move must fail immediately")
	check(enemy.movement.current_cell == cell, "Blocked Move must preserve position")
	if HexGrid.is_valid_cell(destination):
		HexGrid.set_occupied(destination, false)

	# Trap damage may queue_free the moving actor before the scheduler resumes.
	var trap_enemy: Enemy = controller.action_order[2]
	trap_enemy.movement.set_pos(Vector2i(-4, 0))
	var trap_cell := Vector2i(-3, 0)
	HexGrid.set_occupied(trap_cell, false)
	var trap: Trap = load("res://Abilities/Trap.tscn").instantiate()
	arena.add_child(trap)
	trap.setup(HexGrid, trap_cell, 100)
	trap.is_spawning = false
	HexGrid.traps[trap_cell] = trap
	var trap_target := AbilityTarget.new(Global.TargetingType.DIRECTION)
	trap_target.direction = Vector2i(1, 0)
	trap_target.is_valid = true
	var trap_queue := AbilityQueue.new()
	trap_queue.add_ability(trap_enemy.move_ability, trap_target)
	await controller.execute_next(trap_enemy, trap_queue)
	check(not trap_queue.has_entries(), "Trap death must still resolve and consume the action")
	check(trap_enemy.health <= 0 and trap_enemy.is_queued_for_deletion(), "Trap must kill the moving enemy")
	check(not HexGrid.is_occupied(trap_cell), "Dead enemy must release occupancy")

	print("TURN_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)


func record_action(actor: Node, _entry: QueuedAbility) -> void:
	observed.append(actor.action_number)
	for other in controller.action_order:
		if is_instance_valid(other):
			check(not other.movement.is_moving, "Next actor must wait until previous movement completes")
	# execute_next is also tested in isolation after the phase integration test.
	if controller.current_phase != ActionExecutionController.TurnPhase.EXECUTION:
		return
	check(controller.current_phase == ActionExecutionController.TurnPhase.EXECUTION, "Actions must run during execution")
	check(not controller.player_queue._interaction_enabled, "Player editing must stay locked for every actor")
	check(controller.player_actor._action_sequence_active, "Player input must stay locked for the whole phase")
