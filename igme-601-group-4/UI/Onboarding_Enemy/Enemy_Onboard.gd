extends Node

enum TutorialStep {
	SHOW_ENEMY,
}

var current_step: TutorialStep = TutorialStep.SHOW_ENEMY

@export var darken_ui:DarkenUI
@onready var welcome_panel: PanelContainer = $Welcome
@onready var prompt_panel:PanelContainer = $TutorialPrompt
@onready var prompt_text:Label = $TutorialPrompt/TutorialText
@export var enemyParent:Node
@export var enemy:Enemy
@export var task_panel: PanelContainer

signal user_input

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	get_enemy()
	await user_input
	welcome_panel.fade_in()
	welcome_panel.hide()
	start_enemy_tutorial()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton:
		if event.is_released():
			return
	user_input.emit()

func start_enemy_tutorial() -> void:
	#highlight walls
	darken_ui.show()
	
	prompt_panel.show()
	prompt_text.text = "Enemy on the field can damage you!"
	if enemy == null:
		get_enemy()
	darken_ui.highlight_3D(enemy)
	await user_input
	#finish_attack_tutorial()
	
func finish_attack_tutorial() -> void:
	darken_ui.clear()
	prompt_panel.hide()
	HexGrid.set_tutorial_target(Vector2i(4,0))
	#task_panel.show()
	
func get_enemy() -> void:
	enemy = enemyParent.get_child(0)
	print(enemy)
