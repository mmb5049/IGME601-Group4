extends Node3D

class_name Enemy

var health:int = 10
var current_cell: Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func damage(amount:int):
	health -= amount
	print("Enemy health is now: " + str(health))
	if health <= 0:
		die()

func die():
	queue_free()

func set_grid_pos(new_hex:Vector2i) -> bool:
	# check if hex is valid
	if  HexScript.is_valid_cell(new_hex) and HexScript.is_occupied(new_hex):
		print("Hex Occupied")
		return false
	
	# clear old hex
	if current_cell:
		HexScript.set_occupied(current_cell, false)
	
	# occupy new hex
	current_cell = new_hex
	HexScript.set_occupied(current_cell, self)
	position = HexScript.hex_to_world(current_cell) + Vector3(0,1,0)
	return true
