extends Node3D

class_name Obstacle

var current_cell:Vector2i

# Only assign if the wall is destructable
@export var health:Health

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if health:
		health.died.connect(die)

func set_hex_position(cell:Vector2i) -> void:
	var target_position = HexGrid.to_global(HexGrid.hex_to_world(cell))
	
	# Adjust target height
	target_position.y = HexGrid.hex_height/2
	
	# Update occupancy
	if current_cell:
		HexGrid.set_occupied(current_cell, false)
	HexGrid.set_occupied(cell, self as Obstacle)
	
	# Snap position
	global_position = target_position
	current_cell = cell

func die() -> void:
	if current_cell:
		HexGrid.set_occupied(current_cell, false)
	queue_free()
