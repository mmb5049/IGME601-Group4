extends Node
class_name ActionExecutionController

## Emitted once for the complete action phase requested by the player.
signal execution_started
signal execution_finished

## These per-entry signals form the extension points for future animation,
## sound, combat logging, and the full multi-actor turn-order controller.
signal action_started(actor: Node, entry: QueuedAbility)
signal action_finished(actor: Node, entry: QueuedAbility, succeeded: bool)

## This milestone wires one actor and one visible queue. execute_next() itself
## intentionally uses a small method-based contract so a future enemy queue can
## use the same executor without needing an AbilitySequenceUI node.
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


func _ready() -> void:
	if execute_button == null:
		push_error("ActionExecutionController needs an ExecuteButtonUI reference.")
		return
	execute_button.execute_requested.connect(_on_execute_requested)


func _on_execute_requested() -> void:
	# A second click must never start another coroutine over the same queue.
	if _is_executing:
		return
	if player_actor == null or player_queue == null:
		push_error("ActionExecutionController needs a player and player queue.")
		return
	if not player_queue.has_entries():
		return

	_execute_current_player_plan()


## Current milestone behavior: because enemies have empty plans, repeatedly
## executing the player's next entry produces the same visible result as the
## future round-robin scheduler. That scheduler should call execute_next() once
## per actor instead of replacing the ability execution code below.
func _execute_current_player_plan() -> void:
	_is_executing = true
	_set_planning_interaction_enabled(false)
	player_actor.begin_action_sequence()
	execution_started.emit()

	while player_queue.has_entries():
		await execute_next(player_actor, player_queue)
		if player_queue.has_entries() and between_actions_delay > 0.0:
			await get_tree().create_timer(between_actions_delay).timeout

	player_actor.end_action_sequence()
	_set_planning_interaction_enabled(true)
	_is_executing = false
	execution_finished.emit()


## Executes exactly one queue entry. The queue_source contract is deliberately
## small: has_entries(), peek_front_entry(), and consume_entry(id). A later
## enemy-owned, non-visual queue can implement those same methods.
func execute_next(actor: Node, queue_source: Object) -> bool:
	if actor == null or queue_source == null:
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
	action_finished.emit(actor, entry, succeeded)
	return succeeded


func _set_planning_interaction_enabled(enabled: bool) -> void:
	if execute_button != null:
		execute_button.set_interaction_enabled(enabled)
	if player_ability_bar != null:
		player_ability_bar.set_interaction_enabled(enabled)
	if player_queue != null:
		player_queue.set_interaction_enabled(enabled)
