extends CharacterBody3D
class_name PlayerController

## UI and gameplay systems observe these signals instead of duplicating target
## calculations. The Player remains the single authority for legal targets.
signal targeting_started(ability: Ability)
signal target_preview_changed(target: AbilityTarget)
signal targeting_ended
signal ability_confirmed(ability: Ability, target: AbilityTarget)

const INVALID_CELL := Vector2i(2147483647, 2147483647)
const INVALID_WORLD_POSITION := Vector3(INF, INF, INF)

@onready var camera: Camera3D = get_viewport().get_camera_3d()
@export var movement: CharacterMovement
@export var animationManager:AnimationManager

@export_category("Abilities")
@export var abilities: Array[Ability] = []

var selected_ability: Ability = null
var cursor_position: Vector2 = Vector2.ZERO
## Remains true across the small gaps between queued abilities. current_mode
## alone cannot provide this lock because each individual action resets it.
var _action_sequence_active: bool = false

enum PlayerMode {
	NONE,
	TARGETING,
	ACTING,
}

var current_mode: PlayerMode = PlayerMode.NONE


func _ready() -> void:
	cursor_position = get_viewport().get_mouse_position()
	if animationManager:
		animationManager.play_animation(animationManager.idle_animation)


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard selection remains available for the group's temporary testing,
	# but the formal UI flow enters through request_ability below.
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE and current_mode == PlayerMode.TARGETING:
			cancel_targeting()
			get_viewport().set_input_as_handled()
			return

		if current_mode == PlayerMode.ACTING or _action_sequence_active:
			return
		match key_event.keycode:
			KEY_M:
				request_ability(get_ability("Move"))
			KEY_D:
				request_ability(get_ability("Dash"))
			KEY_S:
				request_ability(get_ability("Slash"))

	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed or current_mode != PlayerMode.TARGETING:
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_current_target()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		cursor_position = motion_event.position
		if current_mode == PlayerMode.TARGETING:
			_update_targeting_preview()

func get_ability(ability_name: String) -> Ability:
	for ability in abilities:
		if ability.ability_name == ability_name:
			return ability
	return null

## Entry point for AbilityBar selections. Targeted abilities enter TARGETING;
## NONE abilities can be confirmed and queued immediately.
func request_ability(ability: Ability) -> void:
	if ability == null or current_mode == PlayerMode.ACTING or _action_sequence_active:
		return

	HexGrid.clear_highlights()
	selected_ability = ability
	cursor_position = get_viewport().get_mouse_position()

	if ability.targeting_type == Global.TargetingType.NONE:
		var immediate_target := AbilityTarget.new(Global.TargetingType.NONE)
		immediate_target.is_valid = true
		ability_confirmed.emit(ability, immediate_target)
		selected_ability = null
		current_mode = PlayerMode.NONE
		targeting_ended.emit()
		return

	current_mode = PlayerMode.TARGETING
	targeting_started.emit(ability)
	_update_targeting_preview()

func cancel_targeting() -> void:
	if current_mode != PlayerMode.TARGETING:
		return

	HexGrid.clear_highlights()
	selected_ability = null
	current_mode = PlayerMode.NONE
	targeting_ended.emit()

func _confirm_current_target() -> void:
	if selected_ability == null:
		return

	var target: AbilityTarget = evaluate_target(selected_ability, cursor_position)
	if not target.is_valid:
		return

	var confirmed_ability: Ability = selected_ability
	HexGrid.clear_highlights()
	selected_ability = null
	current_mode = PlayerMode.NONE
	ability_confirmed.emit(confirmed_ability, target)
	targeting_ended.emit()

## Reuses one evaluation result for grid highlighting, indicator feedback, and
## final confirmation so all three always agree about target legality.
func _update_targeting_preview() -> void:
	if selected_ability == null:
		return

	HexGrid.clear_highlights()
	var target: AbilityTarget = evaluate_target(selected_ability, cursor_position)
	var highlight_material: ShaderMaterial = _get_highlight_material(selected_ability)

	match selected_ability.targeting_type:
		Global.TargetingType.DIRECTION:
			for direction: Vector2i in HexGrid.DIRECTIONS:
				HexGrid.highlight_line(
					highlight_material,
					movement.current_cell,
					direction,
					selected_ability.range
				)
			if target.is_valid:
				HexGrid.highlight_line(
					HexGrid.material_select,
					movement.current_cell,
					target.direction,
					selected_ability.range
				)

		Global.TargetingType.SINGLE_TILE:
			var cells: Array[Vector2i] = []
			for radius in range(1, selected_ability.range + 1):
				cells.append_array(HexGrid.get_ring(movement.current_cell, radius))
			HexGrid.highlight_cells(highlight_material, cells)
			if target.is_valid:
				HexGrid.create_highlight(HexGrid.material_select,
					target.target_cell + movement.current_cell)

		Global.TargetingType.SHAPE:
			pass

		Global.TargetingType.NONE:
			pass

	target_preview_changed.emit(target)

func _get_highlight_material(ability: Ability) -> ShaderMaterial:
	if ability.type == Global.AbilityType.MOVEMENT:
		return HexGrid.material_move
	return HexGrid.material_attack

## Produces a typed target without changing UI or grid state.
func evaluate_target(ability: Ability, mouse_position: Vector2) -> AbilityTarget:
	var result := AbilityTarget.new(ability.targeting_type)
	if ability.targeting_type == Global.TargetingType.NONE:
		result.is_valid = true
		return result

	var clicked_cell: Vector2i = get_clicked_hex(mouse_position)
	if clicked_cell == INVALID_CELL or not HexGrid.is_valid_cell(clicked_cell):
		return result

	match ability.targeting_type:
		Global.TargetingType.DIRECTION:
			var clicked_position: Vector3 = get_clicked_pos(mouse_position)
			if not clicked_position.is_finite():
				return result

			var player_position: Vector3 = HexGrid.to_global(
				HexGrid.hex_to_world(movement.current_cell)
			)
			var world_difference: Vector3 = clicked_position - player_position
			var flat_difference := Vector2(world_difference.x, world_difference.z).normalized()
			if flat_difference == Vector2.ZERO:
				return result

			var best_direction := Vector2i.ZERO
			var best_score: float = -INF
			for direction: Vector2i in HexGrid.DIRECTIONS:
				var direction_world: Vector3 = HexGrid.hex_to_world(direction).normalized()
				var score: float = (
					flat_difference.x * direction_world.x
					+ flat_difference.y * direction_world.z
				)
				if score > best_score:
					best_score = score
					best_direction = direction

			result.direction = best_direction
			result.is_valid = best_direction != Vector2i.ZERO
			if result.is_valid and ability.type == Global.AbilityType.MOVEMENT:
				var destination: Vector2i = HexGrid.raycast(
					movement.current_cell,
					best_direction,
					ability.range
				)
				result.is_valid = destination != movement.current_cell

		Global.TargetingType.SINGLE_TILE:
			result.target_cell = clicked_cell
			# checks if cell is in range of player
			result.is_valid = (
				HexGrid.hex_distance(clicked_cell, movement.current_cell) <= ability.range
			)
			# can't move onto current position
			if result.is_valid and ability.type == Global.AbilityType.MOVEMENT:
				result.is_valid = (
					clicked_cell != movement.current_cell
				)
			# make target relative to player position
			result.target_cell -= movement.current_cell

		Global.TargetingType.SHAPE:
			# Shape placement will use the same AbilityTarget object when implemented.
			result.target_cell = clicked_cell

	return result

## Called by the action-phase queue executor. Movement branches suspend until
## CharacterMovement reports completion, giving the controller one consistent
## awaitable API for both asynchronous movement and immediate attacks.
func execute_ability(ability: Ability, target: AbilityTarget) -> bool:
	if ability == null or target == null or not target.is_valid:
		return false

	current_mode = PlayerMode.ACTING
	var succeeded: bool = true
	
	# play animation
	var has_animation:bool = false
	if animationManager:
		has_animation = animationManager.has_animation(ability.animation)
		if has_animation:
			animationManager.play_animation(ability.animation)
	
	match ability.type:
		Global.AbilityType.MOVEMENT:
			var destination: Vector2i = target.target_cell
			
			# set target for direction types
			if ability.targeting_type == Global.TargetingType.DIRECTION:
				if target.direction == Vector2i.ZERO:
					_finish_queued_ability()
					return false
				destination = HexGrid.raycast(
					movement.current_cell,
					target.direction,
					ability.range,
					true
				)
				
			# make sure the cell is not the current one of off the grid
			if destination == movement.current_cell or not HexGrid.is_valid_cell(destination):
				succeeded = false
			else:
				movement.pathfind(destination)
				# CharacterMovement can finish an empty path synchronously. Only
				# await when pathfind actually selected a different target cell.
				if movement.target_cell != movement.current_cell or movement.is_moving:
					await movement.done_moving

		Global.AbilityType.ATTACK:
			# Lambda function that damages the enemy
			var attack = func(_action_num):
				var target_cell: Vector2i = target.target_cell + movement.current_cell
				if HexGrid.is_occupied(target_cell) and HexGrid.occupied_cells[target_cell] is Enemy:
					(HexGrid.occupied_cells[target_cell] as Enemy).damage(ability.damage)
			# if there is an animation, wait for it to finish and only call attack
			# when it lines up with the animation
			if has_animation:
				animationManager.take_action.connect(attack)
				await animationManager.animationPlayer.animation_finished
				animationManager.take_action.disconnect(attack)
			else:
				attack.call(0)
		_:
			# Wait and not-yet-specialized Ability types still consume one
			# queue step. Their gameplay effects can be added here later.
			pass

	_finish_queued_ability()
	return succeeded

func execute_queued_ability(entry: QueuedAbility) -> bool:
	if entry == null or entry.ability == null or entry.target == null:
		return false
	# Propagate the coroutine so callers do not advance past a movement Ability
	# until execute_ability() has received CharacterMovement.done_moving.
	return await execute_ability(entry.ability, entry.target)

## The sequence-level lock prevents planning input between two abilities. The
## current mode therefore remains ACTING until the controller ends the plan.
func _finish_queued_ability() -> void:
	current_mode = PlayerMode.ACTING if _action_sequence_active else PlayerMode.NONE

func begin_action_sequence() -> void:
	_action_sequence_active = true
	current_mode = PlayerMode.ACTING
	HexGrid.clear_highlights()
	selected_ability = null

func end_action_sequence() -> void:
	_action_sequence_active = false
	current_mode = PlayerMode.NONE
	if animationManager:
		animationManager.play_animation(animationManager.idle_animation)

func get_clicked_pos(mouse_position: Vector2) -> Vector3:
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.001:
		return INVALID_WORLD_POSITION

	var grid_y: float = HexGrid.global_position.y
	var distance: float = (grid_y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return INVALID_WORLD_POSITION
	return ray_origin + ray_direction * distance

func get_clicked_hex(mouse_position: Vector2) -> Vector2i:
	var hit_position: Vector3 = get_clicked_pos(mouse_position)
	if not hit_position.is_finite():
		return INVALID_CELL

	var local_position: Vector3 = HexGrid.to_local(hit_position)
	return HexGrid.world_to_hex(local_position)
