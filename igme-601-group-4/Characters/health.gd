extends Node3D

class_name Health

@export var mesh:MeshManager
@onready var number_display = preload("res://Misc/number_display.tscn")

@export_category("Health")
@export var max: int = 20
var current: int = 20
var is_dead: bool = false

signal changed(current_health:int, max_health:int)
signal died

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current = max
	changed.emit(current, max)

func damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	
	# Display damage number
	var new_display:Node3D = number_display.instantiate()
	get_parent().add_child(new_display)
	new_display.global_position = global_position
	new_display.set_number(-amount)
	
	# Flash the mesh white
	if mesh:
		mesh.flash()

	# Change Health
	current = current - amount
	changed.emit(current, max)

	if current <= 0:
		is_dead = true
		died.emit()

# Incomplete function. Nothing heals yet
func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current = mini(current + amount, max)

func copy(health_to_copy:Health):
	current = health_to_copy.current
	max = health_to_copy.max
	is_dead = health_to_copy.is_dead
