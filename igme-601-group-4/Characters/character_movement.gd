extends Node

class_name CharacterMovement

@export var character:Node3D
@export var move_speed:float = 20

var current_cell:Vector2i = Vector2i.ZERO
var target_cell:Vector2i
var path:Array[Vector2i]

signal done_moving(sender:Signal)
var is_moving:bool

func _ready():
	target_cell = current_cell

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

# Creates a path toward
func pathfind(end_cell:Vector2i):
	## Should not pathfind when dashing... 
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
	print("New target is: " + str(target_cell))

# Move character towards target hex. Returns true if the target has been reached
func move_to(cell:Vector2i, delta) -> bool:
	var target_position = HexGrid.to_global(HexGrid.hex_to_world(cell))
	
	# Adjust target height
	target_position.y = HexGrid.hex_height / 2.0 + 0.5
	
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
		HexGrid.set_occupied(target_cell, true)
		
		# Snap position
		character.global_position = target_position
		current_cell = target_cell
		return true
	return false
