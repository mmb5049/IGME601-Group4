extends Node3D

class_name Enemy

@export var movement:CharacterMovement
var health:int = 10

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func damage(amount:int):
	health -= amount
	print("Enemy health is now: " + str(health))
	if health <= 0:
		die()

func die():
	HexGrid.set_occupied(movement.current_cell, false)
	queue_free()

func set_grid_pos(new_hex:Vector2i) -> bool:
	# check if hex is valid
	if  HexGrid.is_valid_cell(new_hex) and HexGrid.is_occupied(new_hex):
		print("Hex Occupied")
		return false
	
	# clear old hex
	if movement.current_cell:
		HexGrid.set_occupied(movement.current_cell, false)
	
	# occupy new hex
	movement.current_cell = new_hex
	movement.target_cell = new_hex
	HexGrid.set_occupied(movement.current_cell, self)
	position = HexGrid.hex_to_world(movement.current_cell) + Vector3(0,1,0)
	return true
