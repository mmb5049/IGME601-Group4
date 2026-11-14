extends Node

enum TutorialStep {
	PROMPT_BREAKABLE_OBJECT,
}

var current_step: TutorialStep = TutorialStep.PROMPT_BREAKABLE_OBJECT

@export var darkenUI: ColorRect
@onready var prompt_panel:PanelContainer = $Prompt
@onready var prompt_text:Label = $Prompt/Text
@export var task_panel: PanelContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	start_attack_tutorial()


func start_attack_tutorial() -> void:
	darkenUI.show()
	darkenUI.ChangeSize(Vector2 (200,300), Vector2 (925,700))
	prompt_panel.show()
	prompt_text.text = "These pillars can be broken using an attack ability"
	await get_tree().create_timer(3.0).timeout
	finish_attack_tutorial()
	
func finish_attack_tutorial() -> void:
	darkenUI.hide()
	prompt_panel.hide()
	HexGrid.set_tutorial_target(Vector2i(4,0))
	task_panel.show()
