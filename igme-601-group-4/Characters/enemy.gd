extends Node3D

class_name Enemy

@export var movement:CharacterMovement
@onready var mesh:MeshInstance3D = $MeshInstance3D
var number_display = preload("res://Misc/number_display.tscn")

var health:int = 10

signal died()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func damage(amount:int):
	health -= amount
	print("Enemy health is now: " + str(health))
	
	var new_display:Node3D = number_display.instantiate()
	get_parent().add_child(new_display)
	
	new_display.global_position = global_position + Vector3(0, 1.1, 0)
	new_display.set_number(-amount)

	mesh.flash()
	
	if health <= 0:
		die()

func die():
	HexGrid.set_occupied(movement.current_cell, false)
	died.emit()
	queue_free()
