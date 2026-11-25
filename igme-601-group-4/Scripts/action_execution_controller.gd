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
@export var player_queue_UI: AbilitySequenceUI
@export var player_ability_bar: AbilityBarUI
@export var enemy_parent:Node3D
@export var execute_button: ExecuteButtonUI

## Instant abilities could otherwise consume several queue entries in one
## frame. This short pause also gives the queue-closing animation time to read.
@export_category("Execution Timing")
@export_range(0.0, 1.0, 0.01, "suffix:s") var between_actions_delay: float = 0.20

var preview_actor: Character
var _is_executing: bool = false
enum TurnPhase { INITIALIZING, PREPARATION, EXECUTION }
var current_phase: TurnPhase = TurnPhase.INITIALIZING
var turn_number: int = 0
## Player first, followed by this turn's shuffled enemies. Readable by future UI.
var action_order: Array[Character] = []
@export var obstacles:Node3D 

func _ready() -> void:
	await get_parent().last_scene_done
	if execute_button == null:
		push_error("ActionExecutionController needs an ExecuteButtonUI reference.")
		return
	execute_button.execute_requested.connect(_on_execute_requested)
	# Arena._ready() spawns enemies after this child becomes ready.
	begin_preparation.call_deferred()
	if not obstacles:
		push_warning("Obstacle parent not set")

func begin_preparation() -> void:
	if _is_executing or current_phase == TurnPhase.PREPARATION:
		return
	if not is_instance_valid(player_actor) or player_actor.health.is_dead:
		return
	turn_number += 1
	action_order.clear()
	player_actor.action_number = 1
	action_order.append(player_actor)
	var enemies: Array[Enemy] = []
	for node in enemy_parent.get_children():
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
	if player_actor == null or player_queue_UI == null:
		push_error("ActionExecutionController needs a player and player queue.")
		return
	if player_actor.health.is_dead or player_actor.current_mode == PlayerController.PlayerMode.TARGETING:
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
			if actor.ability_queue == null or not actor.ability_queue.has_entries():
				continue
			await execute_next(actor, actor.ability_queue)
			if not is_inside_tree():
				return
			if _has_pending_actions() and between_actions_delay > 0.0:
				await get_tree().create_timer(between_actions_delay).timeout
				if not is_inside_tree():
					return

	if is_instance_valid(player_actor):
		player_actor.end_action_sequence()
	_is_executing = false
	execution_finished.emit()
	begin_preparation()


func _actor_can_act(actor: Variant) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	return not actor.health.is_dead

func _has_pending_actions() -> bool:
	if not _actor_can_act(player_actor):
		return false
	for actor in action_order:
		if _actor_can_act(actor):
			if actor.ability_queue != null and actor.ability_queue.has_entries():
				return true
	return false

## Executes exactly one queue entry. The queue_source contract is deliberately
## small: has_entries(), peek_front_entry(), and consume_entry(id).
func execute_next(actor: Character, queue_source: AbilityQueue) -> bool:
	if not _actor_can_act(actor) or not is_instance_valid(queue_source):
		return false
	if not bool(queue_source.call("has_entries")):
		return false

	var entry: QueuedAbility = queue_source.peek_front_entry()
	if entry == null:
		return false

	action_started.emit(actor, entry)
	# await also accepts an immediate return value. Movement abilities suspend
	# here until CharacterMovement emits done_moving; attacks and Wait complete
	# synchronously and proceed directly to queue consumption.
	@warning_ignore("redundant_await")
	var succeeded: bool = await actor.execute_queued_ability(entry)
	# Cancelling a presentation during scene removal can resume this after exit.
	if not is_inside_tree():
		return false
	if(actor is PlayerController):
		player_queue_UI.consume_entry(entry.id)
	else:
		queue_source.consume_entry(entry.id)
	action_finished.emit(actor if is_instance_valid(actor) else null, entry, succeeded)
	return succeeded

func _set_planning_interaction_enabled(enabled: bool) -> void:
	if execute_button != null:
		execute_button.set_interaction_enabled(enabled)
	if player_ability_bar != null:
		player_ability_bar.set_interaction_enabled(enabled)
	if player_queue_UI != null:
		player_queue_UI.set_interaction_enabled(enabled)

# The selected actor's turn starts after earlier actors in the same pass.
func preview_queue(index: int, selected_actor: Character = player_actor) -> void:
	if current_phase != TurnPhase.PREPARATION or not _actor_can_act(selected_actor):
		return
	preview_actor = selected_actor
	HexGrid.clear_highlights()
	HexGrid.occupied_cells_preview.clear()
	for character in action_order:
		if not _actor_can_act(character):
			continue
		character.hologram.reset()
		character.hologram.show()
		character.mesh.hide()
		character.user_interface.show_ui()
		character.user_interface.global_position = character.global_position
		if character is Enemy:
			character._health_bar._update_health(character.health.current, character.health.max, false)

	if obstacles:
		for obstacle in obstacles.get_children():
			if obstacle is Obstacle and obstacle.hologram:
				obstacle.hologram.reset()
				obstacle.hologram.show()
				obstacle.mesh.hide()

	for round_index in range(index + 1):
		for character in action_order:
			if player_actor.hologram.health.is_dead:
				return
			if not _actor_can_act(character):
				continue
			var ghost := character.hologram
			if round_index == index and character == selected_actor:
				var selected := ghost.ability_queue.peek_front_entry()
				if selected and not ghost.health.is_dead:
					character.update_ability_preview(ghost.movement.current_cell,
							selected.ability, false, selected.target)
				return
			if ghost.health.is_dead or not ghost.ability_queue.has_entries():
				continue
			var entry := ghost.ability_queue.peek_front_entry()
			ghost.execute_queued_ability(entry)
			ghost.ability_queue.consume_entry(entry.id)
			character.user_interface.global_position = ghost.global_position

func clear_preview() -> void:
	preview_actor = null
	for character in action_order:
		if not _actor_can_act(character):
			continue
		character.hologram.hide()
		character.mesh.show()
		character.user_interface.show_ui()
		character.user_interface.global_position = character.global_position
		if character is Enemy:
			character._health_bar._update_health(character.health.current, character.health.max)
	if obstacles:
		for obstacle in obstacles.get_children():
			if obstacle is Obstacle and obstacle.hologram:
				obstacle.hologram.visible = false
				obstacle.mesh.visible = true
