extends Node

class_name SceneTransition

@export var glitch_tv : ColorRect
var is_transitioning: bool = false

@export var next_stage:PackedScene
# has to be a file path to avoid circular referencing
@export_file("*.tscn", "*.scn") var original_stage_path:String
var original_stage:PackedScene
@export var final_stage:bool 
@onready var arena_manager:ArenaManager = $".."

func _ready() -> void:
	if original_stage_path:
		original_stage = load(original_stage_path)
	HexGrid.tutorial_target_completed.connect(_on_tutorial_target_completed)

func _on_tutorial_target_completed() -> void:
	HexGrid.clear_goal()
	move_scene()

func move_scene() -> void:
	if final_stage:
		arena_manager.game_over(true)
	else:
		glitch_tv.show()
		await get_tree().create_timer(2.0).timeout
		var new_scene:ArenaManager = next_stage.instantiate()
		new_scene.current_level = arena_manager.current_level
		Global.switch_scenes(new_scene)
