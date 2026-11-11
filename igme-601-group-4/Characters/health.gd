extends Node3D

class_name Health

@export var mesh:MeshManager
@onready var number_display = preload("res://Misc/number_display.tscn")

@export_category("Health")
@export var max_health: int = 20
var current_health: int = 20
var is_dead: bool = false

signal health_changed(current_health:int, max_health:int)
signal died

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	
	# Display damage number
	var new_display:Node3D = number_display.instantiate()
	get_parent().add_child(new_display)
	new_display.set_number(-amount)
	
	# Flash the mesh white
	if mesh:
		mesh.flash()

	# Change Health
	current_health = current_health - amount
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		is_dead = true
		died.emit()

# Incomplete function. Nothing heals yet
func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
