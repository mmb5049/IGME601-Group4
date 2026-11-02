extends Node
class_name ActionExecutionController

## Emitted once for the complete action phase requested by the player.
signal execution_started
signal execution_finished

signal preparation_started(turn_number: int)
signal phase_changed(phase: TurnPhase)

## Per-entry extension points for animation, UI, and combat logging.
signal action_started(actor: Node, entry: QueuedAbility)
signal action_finished(actor: Node, entry: QueuedAbility, succeeded: bool)

@export_category("Current Player Plan")
@export var player_actor: PlayerController
@export var player_queue: AbilitySequenceUI
@export var player_ability_bar: AbilityBarUI
@export var execute_button: ExecuteButtonUI

## Instant abilities could otherwise consume several queue entries in one
## frame. This short pause also gives the queue-closing animation time to read.
@export_category("Execution Timing")
@export_range(0.0, 1.0, 0.01, "suffix:s") var between_actions_delay: float = 0.20

var _is_executing: bool = false
enum TurnPhase { INITIALIZING, PREPARATION, EXECUTION }
var current_phase: TurnPhase = TurnPhase.INITIALIZING
var turn_number: int = 0
## Player first, followed by this turn's shuffled enemies. Readable by future UI.
var action_order: Array[Node] = []


func _ready() -> void:
	if execute_button == null:
		push_error("ActionExecutionController needs an ExecuteButtonUI reference.")
		return
	execute_button.execute_requested.connect(_on_execute_requested)
	# Arena._ready() spawns enemies after this child becomes ready.
	begin_preparation.call_deferred()


func begin_preparation() -> void:
	if _is_executing or current_phase == TurnPhase.PREPARATION:
		return
	if not is_instance_valid(player_actor) or player_actor.is_dead:
		return
	turn_number += 1
	action_order.clear()
	player_actor.action_number = 1
	action_order.append(player_actor)
	var enemies: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and get_parent().is_ancestor_of(node) and _actor_can_act(node):
			enemies.append(node)
	enemies.shuffle()
	for index in range(enemies.size()):
		var enemy: Enemy = enemies[index]
		enemy.action_number = index + 2
		enemy.prepare_turn(player_actor)
		action_order.append(enemy)
	current_phase = TurnPhase.PREPARATION
	_set_planning_interaction_enabled(true)
	phase_changed.emit(current_phase)
	preparation_started.emit(turn_number)


func _on_execute_requested() -> void:
	# A second click must never start another coroutine over the same queue.
	if _is_executing or current_phase != TurnPhase.PREPARATION:
		return
	if player_actor == null or player_queue == null:
		push_error("ActionExecutionController needs a player and player queue.")
		return
	if player_actor.is_dead or player_actor.current_mode == PlayerController.PlayerMode.TARGETING:
		return

	_execute_turn()


## One entry per living actor per pass, until every queue is exhausted.
func _execute_turn() -> void:
	_is_executing = true
	current_phase = TurnPhase.EXECUTION
	_set_planning_interaction_enabled(false)
	player_actor.begin_action_sequence()
	phase_changed.emit(current_phase)
	execution_started.emit()

	while _has_pending_actions():
		for actor in action_order:
			if not _actor_can_act(player_actor):
				break
			if not _actor_can_act(actor):
				continue
			var queue: Object = _get_actor_queue(actor)
			if queue == null or not queue.has_entries():
				continue
			await execute_next(actor, queue)
			if _has_pending_actions() and between_actions_delay > 0.0:
				await get_tree().create_timer(between_actions_delay).timeout

	if is_instance_valid(player_actor):
		player_actor.end_action_sequence()
	_is_executing = false
	execution_finished.emit()
	begin_preparation()


func _actor_can_act(actor: Variant) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	if actor is Enemy:
		return actor.health > 0
	if actor is PlayerController:
		return not actor.is_dead
	return false


func _get_actor_queue(actor: Node) -> Object:
	if actor == player_actor:
		return player_queue
	if actor is Enemy:
		return actor.ability_queue
	return null


func _has_pending_actions() -> bool:
	if not _actor_can_act(player_actor):
		return false
	for actor in action_order:
		if _actor_can_act(actor):
			var queue: Object = _get_actor_queue(actor)
			if queue != null and queue.has_entries():
				return true
	return false


## Executes exactly one queue entry. The queue_source contract is deliberately
## small: has_entries(), peek_front_entry(), and consume_entry(id).
func execute_next(actor: Node, queue_source: Object) -> bool:
	if not _actor_can_act(actor) or not is_instance_valid(queue_source):
		return false
	if (
		not queue_source.has_method("has_entries")
		or not queue_source.has_method("peek_front_entry")
		or not queue_source.has_method("consume_entry")
		or not actor.has_method("execute_queued_ability")
	):
		push_error("Actor or queue source does not implement the action execution contract.")
		return false
	if not bool(queue_source.call("has_entries")):
		return false

	var entry: QueuedAbility = queue_source.call("peek_front_entry") as QueuedAbility
	if entry == null:
		return false

	action_started.emit(actor, entry)
	# await also accepts an immediate return value. Movement abilities suspend
	# here until CharacterMovement emits done_moving; attacks and Wait complete
	# synchronously and proceed directly to queue consumption.
	var succeeded: bool = bool(await actor.call("execute_queued_ability", entry))
	queue_source.call("consume_entry", entry.id)
	action_finished.emit(actor if is_instance_valid(actor) else null, entry, succeeded)
	return succeeded


func _set_planning_interaction_enabled(enabled: bool) -> void:
	if execute_button != null:
		execute_button.set_interaction_enabled(enabled)
	if player_ability_bar != null:
		player_ability_bar.set_interaction_enabled(enabled)
	if player_queue != null:
		player_queue.set_interaction_enabled(enabled)
