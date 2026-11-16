extends Node

enum TutorialStep {
	PROMPT_BREAKABLE_OBJECT,
}

var current_step: TutorialStep = TutorialStep.PROMPT_BREAKABLE_OBJECT

@export var darken_ui:DarkenUI
@onready var prompt_panel:PanelContainer = $Prompt
@onready var prompt_text:Label = $Prompt/Text
@export var task_panel: PanelContainer

signal user_input

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	start_attack_tutorial()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton:
		if event.is_released():
			return
	user_input.emit()

func start_attack_tutorial() -> void:
	#highlight walls
	darken_ui.show()
	
	
	prompt_panel.show()
	prompt_text.text = "Some pillars can be broken using an attack ability"
	await user_input
	finish_attack_tutorial()
	
func finish_attack_tutorial() -> void:
	darken_ui.clear()
	prompt_panel.hide()
	HexGrid.set_tutorial_target(Vector2i(4,0))
	task_panel.show()
