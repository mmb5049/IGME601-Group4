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
