extends Node

class_name CharacterMovement

@export var character:Node3D
@export var move_speed:float = 20
## Rotate the body separately from collision shapes and overhead UI.
@export var facing_visual: Node3D

const BLOCKED_ADVANCE_DURATION: float = 0.10
const BLOCKED_RETURN_DURATION: float = 0.06
const BLOCKED_SHAKE_DURATION: float = 0.5
const BLOCKED_ADVANCE_RATIO: float = 0.5
const BLOCKED_SHAKE_RATIO: float = 0.09

var _blocked_tween: Tween
var _blocked_origin: Vector3
var _blocked_sideways: Vector3

@export var spawn_position:Vector2i = Vector2i.ZERO
var current_cell:Vector2i
var target_cell:Vector2i
var path:Array[Vector2i]

var floorHeight:float 

signal done_moving(sender:Signal)
var is_moving:bool

@export var hologram:Node3D

func _ready():
	target_cell = current_cell
	floorHeight = HexGrid.hex_height
	
	# Release an awaiting queue action if its actor dies during feedback.
	if character.has_signal("player_died"):
		character.connect("player_died", _finish_blocked_move)
	elif character.has_signal("died"):
		character.connect("died", _finish_blocked_move)

func _physics_process(delta):
	if(target_cell != current_cell):
		# Move to the target cell 
		var reached_target = move_to(target_cell,delta)
		if (reached_target):			
			# Find next cell in the path
			if path and not path.is_empty():
				target_cell = path.pop_front()
				is_moving = true
			else:
				is_moving = false
				done_moving.emit(done_moving)
		else:
			is_moving = true

## Shared by player and enemy directional movement abilities.
func execute_directional_move(direction: Vector2i, distance: int) -> bool:
	if direction == Vector2i.ZERO or distance <= 0:
		return false
	face_movement_direction(
		HexGrid.to_global(HexGrid.hex_to_world(current_cell + direction))
		- HexGrid.to_global(HexGrid.hex_to_world(current_cell))
	)
	var destination: Vector2i = HexGrid.raycast(current_cell, direction, distance, 
	Global.OccupiedType.STATIC | Global.OccupiedType.DYNAMIC)
	if destination == current_cell or not HexGrid.is_valid_cell(destination):
		await _play_blocked_move(direction)
		return false
	pathfind(destination)
	if target_cell == current_cell and not is_moving:
		await _play_blocked_move(direction)
		return false
	await done_moving
	return true


## Models use +Z as their front, matching ability presentation look_at calls.
func face_movement_direction(direction: Vector3) -> void:
	direction.y = 0.0
	if not is_instance_valid(facing_visual) or direction.length_squared() < 0.0001:
		return
	facing_visual.look_at(facing_visual.global_position + direction, Vector3.UP, true)


## Cosmetic motion only: keep the logical cell, occupancy and traps unchanged.
## The normal movement completion signal also gates the entire feedback.
func _play_blocked_move(direction: Vector2i) -> void:
	_blocked_origin = character.global_position
	var step: Vector3 = (
		HexGrid.to_global(HexGrid.hex_to_world(current_cell + direction))
		- HexGrid.to_global(HexGrid.hex_to_world(current_cell))
	)
	step.y = 0.0
	_blocked_sideways = step.normalized().cross(Vector3.UP) * step.length() * BLOCKED_SHAKE_RATIO
	is_moving = true
	_blocked_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_blocked_tween.tween_property(
		character, "global_position", _blocked_origin + step * BLOCKED_ADVANCE_RATIO,
		BLOCKED_ADVANCE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_blocked_tween.tween_property(
		character, "global_position", _blocked_origin, BLOCKED_RETURN_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_blocked_tween.tween_method(_shake_blocked_move, 0.0, 1.0, BLOCKED_SHAKE_DURATION)
	_blocked_tween.finished.connect(_finish_blocked_move)
	await done_moving


func _shake_blocked_move(progress: float) -> void:
	# Sideways oscillations, fading out without changing world height.
	character.global_position = _blocked_origin + _blocked_sideways * sin(progress * TAU * 5.0) * (1.0 - progress)


func _finish_blocked_move() -> void:
	if _blocked_tween == null:
		return
	_blocked_tween.kill()
	_blocked_tween = null
	if is_instance_valid(character):
		character.global_position = _blocked_origin
	is_moving = false
	done_moving.emit(done_moving)


func _exit_tree() -> void:
	_finish_blocked_move()


# Creates a path toward the requested destination.
func pathfind(end_cell:Vector2i):
	path = HexGrid.find_path(current_cell, end_cell)
	## Old code... Checks if path has enough tiles to move
	if path.is_empty():
		done_moving.emit(done_moving)
		return
	path.pop_front()
	if path.is_empty():
		done_moving.emit(done_moving)
		return
	
	HexGrid.set_occupied(current_cell, false)
	target_cell = path.pop_front()

## returns the end position when using a movement ability. Does not consider dynamic blockers (enemies)
func get_destination(ability: Ability, target: AbilityTarget, start:Vector2i) -> Vector2i:
	if ability.type != Global.AbilityType.MOVEMENT:
		return start
	match ability.targeting_type:
		Global.TargetingType.DIRECTION:
			return HexGrid.raycast(start, target.direction, ability.range, Global.OccupiedType.STATIC)
		Global.TargetingType.SINGLE_TILE:
			return target.target_cell
	return start

# Move character towards target hex. Returns true if the target has been reached
func move_to(cell:Vector2i, delta) -> bool:
	var target_position = HexGrid.to_global(HexGrid.hex_to_world(cell))
	
	# Adjust target height
	target_position.y = floorHeight
	face_movement_direction(target_position - character.global_position)
	
	# Set speed
	var current_speed = move_speed
	
	# Move character
	character.global_position = character.global_position.move_toward(
		target_position,
		current_speed * delta
	)
	
	# Check if target reached
	if character.global_position.distance_to(target_position) < 0.01:
		# Update occupancy
		HexGrid.set_occupied(current_cell, false)
		HexGrid.set_occupied(target_cell, character)
		# Snap position
		character.global_position = target_position
		current_cell = target_cell
		HexGrid.trigger_trap(current_cell, get_parent())
		return true
	return false

func set_pos(cell:Vector2i):
	_finish_blocked_move()
	var target_position = HexGrid.to_global(HexGrid.hex_to_world(cell))
	
	# Adjust target height
	target_position.y = floorHeight
	
	# Update occupancy
	if current_cell:
		HexGrid.set_occupied(current_cell, false)
	HexGrid.set_occupied(cell, character)
	
	# Snap position
	character.global_position = target_position
	current_cell = cell
	target_cell = current_cell

func set_hologram_pos(cell:Vector2i):
	if hologram:
		hologram.visible = true
		
		var target_position = HexGrid.to_global(HexGrid.hex_to_world(cell))
		# Adjust target height
		target_position.y = floorHeight
		hologram.global_position = target_position
	else:
		push_error("No hologram pivot set")
