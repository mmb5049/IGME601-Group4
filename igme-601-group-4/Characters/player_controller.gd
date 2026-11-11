extends CharacterBody3D
class_name PlayerController

## UI and gameplay systems observe these signals instead of duplicating target
## calculations. The Player remains the single authority for legal targets.

signal targeting_started(ability: Ability)
signal target_preview_changed(target: AbilityTarget)
signal targeting_ended
signal ability_confirmed(ability: Ability, target: AbilityTarget)
signal mana_changed(current_mana: int, max_mana: int)
signal notification_requested(message: String)

@onready var action_execution_controller := $"../ActionExecutionController"

var number_display = preload("res://Misc/number_display.tscn")
@export var mesh:MeshInstance3D

const INVALID_CELL := Vector2i(2147483647, 2147483647)
const INVALID_WORLD_POSITION := Vector3(INF, INF, INF)

@onready var camera: Camera3D = get_viewport().get_camera_3d()
@export var movement: CharacterMovement
@export var animationManager:AnimationManager
## Outer pivot isolates procedural movement from AnimationPlayer root tracks.
@export var presentation_visual: Node3D

@onready var health:Health = $Health

@export_category("Mana")
@export var max_mana: int = 100
@export var mana_per_turn: int = 100
@export var current_mana: int = 100

@export_category("Abilities")
@export var abilities: Array[Ability] = []
@export var self_enhance_effect_scene: PackedScene

var self_enhance_stacks: int = 0
var self_enhance_effect: Node3D = null

const SELF_ENHANCE_MULTIPLIER: float = 1.5

@export var ability_sequence_ui: AbilitySequenceUI

var _attack_ability: Ability = null
var _attack_target: AbilityTarget = null
var _attack_applied: bool = false

var selected_ability: Ability = null
var cursor_position: Vector2 = Vector2.ZERO
## Remains true across the small gaps between queued abilities. current_mode
## alone cannot provide this lock because each individual action resets it.
var _action_sequence_active: bool = false
signal action_number_changed(number: int)

var action_number: int = 1:
	set(value):
		action_number = value
		action_number_changed.emit(value)

enum PlayerMode {
	NONE,
	TARGETING,
	ACTING,
}

var current_mode: PlayerMode = PlayerMode.NONE


func _ready() -> void:
	movement.set_pos(movement.spawn_position)
	
	cursor_position = get_viewport().get_mouse_position()
	
	if animationManager:
		animationManager.play_animation(animationManager.idle_animation)
	
	mesh = animationManager.get_node("Skeleton3D/Cube")
	ability_sequence_ui.ability_removed.connect(
	func(ability: Ability):
		refund_mana(ability.cost)
	)
	Global.player = self
	
	## TODO: There is a weird bug where setting the occupancy at on_ready doesn't 
	## allow the enemies to read that a player is on this tile. Setting the position 
	## shortly after fixes this...
	await get_tree().create_timer(0.1).timeout
	movement.set_pos(movement.current_cell)

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
			KEY_T:
				request_ability(get_ability("Trap"))
			KEY_A:
				request_ability(get_ability("Attack_Up"))

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
			update_ability_preview(estimate_future_position())

func get_ability(ability_name: String) -> Ability:
	for ability in abilities:
		if ability.ability_name == ability_name:
			return ability
	return null

## Entry point for AbilityBar selections. Targeted abilities enter TARGETING;
## NONE abilities can be confirmed and queued immediately.
func request_ability(ability: Ability) -> void:
	if ability == null or current_mode == PlayerMode.ACTING or _action_sequence_active:
		print("ability: ", ability)
		print("current mode: ", current_mode)
		print("request fail")
		return
		
	if not can_afford_ability(ability):
		show_mana_message("Not enough mana!")
		return
		
	clear_preview()
	selected_ability = ability
	cursor_position = get_viewport().get_mouse_position()

	if ability.targeting_type == Global.TargetingType.NONE:
		var immediate_target := AbilityTarget.new(Global.TargetingType.NONE)
		immediate_target.is_valid = true
		
		# Don't confirm ability if not enough mana
		if not spend_mana(ability.cost):
			show_mana_message("Not enough mana!")
			selected_ability = null
			current_mode = PlayerMode.NONE
			return
			
		ability_confirmed.emit(ability, immediate_target)
		selected_ability = null
		current_mode = PlayerMode.NONE
		targeting_ended.emit()
		return

	current_mode = PlayerMode.TARGETING
	targeting_started.emit(ability)
	update_ability_preview(estimate_future_position())

func cancel_targeting() -> void:
	if current_mode != PlayerMode.TARGETING:
		return

	clear_preview()
	selected_ability = null
	current_mode = PlayerMode.NONE
	targeting_ended.emit()

func _confirm_current_target() -> void:
	if selected_ability == null:
		return

	var target: AbilityTarget = evaluate_target(selected_ability, cursor_position, estimate_future_position())
	if not target.is_valid:
		return

	var confirmed_ability: Ability = selected_ability
	clear_preview()
	selected_ability = null
	current_mode = PlayerMode.NONE
	if not can_afford_ability(confirmed_ability):
		show_mana_message("Not enough mana!")
		cancel_targeting()
		return

	if not spend_mana(confirmed_ability.cost):
		show_mana_message("Not enough mana!")
		cancel_targeting()
		return
		
	ability_confirmed.emit(confirmed_ability, target)
	targeting_ended.emit()

## Reuses one evaluation result for grid highlighting, indicator feedback, and
## final confirmation so all three always agree about target legality.
func update_ability_preview(origin:Vector2i = movement.current_cell, ability = selected_ability, 
show_possible:bool = true, target:AbilityTarget  = null) -> void:
	var possible_material: ShaderMaterial = _get_target_material(ability)
	var target_material: ShaderMaterial = HexGrid.material_select
	
	if ability:
		if not target:
			target = evaluate_target(ability, cursor_position, origin)
		else:
			# use color to show ability type when previewing
			target_material = possible_material
	
	clear_preview()
	
	# Display hologram
	if origin != movement.current_cell:
		movement.set_hologram_pos(origin)
	
	match ability.targeting_type:
		Global.TargetingType.DIRECTION:
			if show_possible:
				for direction: Vector2i in HexGrid.DIRECTIONS:
					HexGrid.highlight_line(
						possible_material,
						origin,
						direction,
						ability.range
					)
			if target and target.is_valid:
				HexGrid.highlight_line(
					target_material,
					origin,
					target.direction,
					ability.range
				)

		Global.TargetingType.SINGLE_TILE:
			if show_possible:
				var cells: Array[Vector2i] = []
				for radius in range(1, ability.range + 1):
					cells.append_array(HexGrid.get_ring(origin, radius))
				HexGrid.highlight_cells(possible_material, cells)
			if target and target.is_valid:
				HexGrid.create_highlight(target_material,
					target.target_cell + origin)

		Global.TargetingType.ANNULAR:
			if show_possible:
				var cells: Array[Vector2i] = []
				for radius in range(1, ability.range + 1):
					cells.append_array(HexGrid.get_ring(origin, radius))
				HexGrid.highlight_cells(possible_material, cells)
			if target and target.is_valid:
				HexGrid.highlight_cells(target_material, target.resolve_cells(origin))

		Global.TargetingType.SHAPE:
			pass

		Global.TargetingType.NONE:
			pass

	target_preview_changed.emit(target)

func _get_target_material(ability: Ability) -> ShaderMaterial:
	if ability.type == Global.AbilityType.MOVEMENT:
		return HexGrid.material_move
	return HexGrid.material_attack

## Produces a typed target without changing UI or grid state.
func evaluate_target(ability: Ability, mouse_position: Vector2, origin:Vector2i) -> AbilityTarget:
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
				HexGrid.hex_to_world(origin)
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
					origin,
					best_direction,
					ability.range
				)
				result.is_valid = destination != origin

		Global.TargetingType.SINGLE_TILE:
			result.target_cell = clicked_cell
			# checks if cell is in range of player
			result.is_valid = (
				HexGrid.hex_distance(clicked_cell, origin) <= ability.range
			)
			# can't move onto current position
			if result.is_valid and ability.type == Global.AbilityType.MOVEMENT:
				result.is_valid = (
					clicked_cell != origin
				)
			# make target relative to player position
			result.target_cell -= origin

		Global.TargetingType.SHAPE:
			# Shape placement will use the same AbilityTarget object when implemented.
			result.target_cell = clicked_cell

		Global.TargetingType.ANNULAR:
			var radius: int = HexGrid.hex_distance(clicked_cell,origin)
			if radius >= 1 and radius <= ability.range:
				result.ring_radius = radius
				result.target_cells = HexGrid.get_ring(Vector2i.ZERO, radius)
				result.is_valid = true

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
		if has_animation and ability.presentation == null:
			animationManager.play_animation(ability.animation)
	
	match ability.type:
		Global.AbilityType.MOVEMENT: 
			## sister function "get_destination" in movement. Make sure to update when
			## changing functionality here
			if ability.targeting_type == Global.TargetingType.ANNULAR:
				# A ring has no single movement destination.
				succeeded = false
			elif ability.targeting_type == Global.TargetingType.DIRECTION:
				succeeded = await movement.execute_directional_move(target.direction, ability.range)
			else:
				var destination: Vector2i = target.target_cell
				if destination == movement.current_cell or not HexGrid.is_valid_cell(destination):
					succeeded = false
				else:
					movement.pathfind(destination)
					if movement.target_cell != movement.current_cell:
						await movement.done_moving

		Global.AbilityType.ATTACK:
			_attack_ability = ability
			_attack_target = target
			_attack_applied = false

			if ability.presentation != null:
				var completed: bool = await ability.presentation.play(self, presentation_visual, target)
				if completed and not health.is_dead:
					_apply_attack()
				else:
					succeeded = false
			elif has_animation:
				animationManager.take_action.connect(_apply_attack)
				await animationManager.animationPlayer.animation_finished
				if animationManager.take_action.is_connected(_apply_attack):
					animationManager.take_action.disconnect(_apply_attack)
				# Fallback: does nothing if the keyframe already fired.
				if not _attack_applied:
					push_warning("take_action never fired; applying attack as fallback")
				_apply_attack()
			else:
				_apply_attack()
			_attack_ability = null
			_attack_target = null
				
		Global.AbilityType.TRAP:
			succeeded = false
			for trap_cell: Vector2i in target.resolve_cells(movement.current_cell):
				if not HexGrid.traps.has(trap_cell):
					if HexGrid.place_trap(trap_cell, ability.damage):
						succeeded = true

		Global.AbilityType.STATUS:
			activate_self_enhance()
		
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
	clear_preview()
	selected_ability = null

func end_action_sequence() -> void:
	_action_sequence_active = false
	current_mode = PlayerMode.NONE

	# Reset Self Enhance stacks.
	self_enhance_stacks = 0

	# Remove visual effect.
	if is_instance_valid(self_enhance_effect):
		self_enhance_effect.queue_free()

	self_enhance_effect = null

	
	# Restore mana for the next turn.
	refill_mana()
	
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
	

func spend_mana(amount: int) -> bool:
	if amount < 0 or current_mana < amount:
		return false

	current_mana -= amount
	mana_changed.emit(current_mana, max_mana)
	return true

func refill_mana() -> void:
	current_mana = mini(
		current_mana + mana_per_turn,
		max_mana
	)
	mana_changed.emit(current_mana, max_mana)

func show_mana_message(message: String) -> void:
	notification_requested.emit(message)
	
func can_afford_ability(ability: Ability) -> bool:
	return ability != null and current_mana >= ability.cost

## Connected to AnimationManager.take_action, and also called directly as a fallback.
func _apply_attack(_action_num:int = 0) -> void:
	# action_num is for attacks triggered by anumations.
	# if we want to deal damage multiple times in one ability,
	# this number signifies the index of which attack it is
	
	if _attack_applied or _attack_ability == null or _attack_target == null:
		return
	_attack_applied = true

	var final_damage: int = _attack_ability.damage
	if self_enhance_stacks > 0:
		var multiplier: float = pow(SELF_ENHANCE_MULTIPLIER, self_enhance_stacks)
		final_damage = roundi(final_damage * multiplier)

	for target_cell: Vector2i in _attack_target.resolve_cells(movement.current_cell):
		var victim: Variant = HexGrid.occupied_cells.get(target_cell)
		if is_instance_valid(victim) and victim is Enemy and not victim.is_queued_for_deletion():
			victim.health.damage(final_damage)
		else:
			var new_display: Node3D = number_display.instantiate()
			get_parent().add_child(new_display)
			new_display.global_position = HexGrid.hex_to_world(target_cell) + Vector3(0, 0.5, 0)
			new_display.set_number(0)

func activate_self_enhance() -> void:
	# Every activation adds another stack.
	self_enhance_stacks += 1

	# Only spawn the effect if one doesn't already exist.
	if not is_instance_valid(self_enhance_effect):
		if self_enhance_effect_scene:
			self_enhance_effect = self_enhance_effect_scene.instantiate()
			add_child(self_enhance_effect)

			# Position underneath the player.
		self_enhance_effect.position = Vector3(0, 0, 0)
		print("Self Enhance stacks: ", self_enhance_stacks)
		
		
func refund_mana(amount: int) -> void:
	if amount <= 0:
		return

	current_mana = mini(current_mana + amount, max_mana)
	mana_changed.emit(current_mana, max_mana)

	print("Mana refunded: ", amount, " | Current mana: ", current_mana)

# returns the grid position if movement is not interupted
# pass in an int to get a specific spot in queue, otherwise it will go to the end
func estimate_future_position(index:int = -1) -> Vector2i:
	var queue:Array[QueuedAbility] = action_execution_controller.player_queue.queued_entries
	var estimated_position:Vector2i = movement.current_cell
	# Get the end of the queue
	if index == -1:
		index = queue.size()
	# Loop through existing queue to get estimated position
	for i in range(0,index):
		if queue[i].ability.type == Global.AbilityType.MOVEMENT:
			estimated_position = movement.get_destination(queue[i].ability,queue[i].target,estimated_position)
	return estimated_position

func clear_preview() -> void:
	HexGrid.clear_highlights()
	if movement.hologram:
		movement.hologram.visible = false
