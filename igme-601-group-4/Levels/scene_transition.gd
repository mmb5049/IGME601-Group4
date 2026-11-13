extends Node

@export var glitch_tv : ColorRect
var is_transitioning: bool = false

@export var NEXT_SCENE:PackedScene


func _ready() -> void:
	HexGrid.tutorial_target_completed.connect(_on_tutorial_target_completed)


func _on_tutorial_target_completed() -> void:
	HexGrid.clear_tutorial_target()
	move_scene()
	

func move_scene() -> void:
	glitch_tv.show()
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_packed(NEXT_SCENE)
