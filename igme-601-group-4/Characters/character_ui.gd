extends Node3D

class_name CharacterUI

@export var action_number:ActionNumberUI
@export var ability_queue:EnemyAbilityQueueUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func show_ui():
	visible = true
	if action_number:
		action_number._show_number()
	if ability_queue:
		ability_queue._show_ui()
	
func hide_ui():
	visible = false
	if action_number:
		action_number._hide_number()
	if ability_queue:
		ability_queue._hide_ui()
