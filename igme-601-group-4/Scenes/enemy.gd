extends Node3D

class_name Enemy

var health:int = 10
var current_cell: Vector2i = Vector2i.ZERO

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

func set_grid_pos(hex:Vector2i):
	position = HexScript.hex_to_world(hex) + Vector3(0,1,0)
	print(position)
