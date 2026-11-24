extends Node

enum TutorialStep {
	SHOW_ENEMY,
	PROMP_HOVER,
	HOVER_ENEMY,
	PROMPT_ABILITY,
	SELECT_ABILITY,
	CHOOSE_DIRECTION
}

var current_step: TutorialStep = TutorialStep.SHOW_ENEMY

@export var ability_bar: AbilityBarUI
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
	ability_bar.ability_selected.connect(_on_ability_selected)
	
	await user_input
	await get_tree().process_frame
	welcome_panel.fade_in()
	welcome_panel.hide()
	start_enemy_tutorial()

func _input(event: InputEvent) -> void:
	# Ignore mouse movement and hovering
	if event is InputEventMouseMotion:
		return
		
	# Only trigger on the exact frame a mouse button or key is pressed down
	if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed() and not event.is_echo():
		user_input.emit()

func start_enemy_tutorial() -> void:
	if enemy == null:
		get_enemy()
	
	darken_ui.highlight_3D(enemy)
	prompt_panel.show()
	prompt_text.text = "Enemy on the field can damage you!"
	await user_input
	await get_tree().process_frame
	
	current_step = TutorialStep.PROMP_HOVER
	prompt_hover()

func prompt_hover()-> void:
	if current_step != TutorialStep.PROMP_HOVER:
		return
	prompt_text.text = "Hover over the enemy to learn more!"
	darken_ui.clear()
	current_step = TutorialStep.HOVER_ENEMY
	
func hover_enemy() -> void:
	if current_step != TutorialStep.HOVER_ENEMY:
		return
	
	prompt_text.text = "Enemy have their own ability queue \n And the number 2 mean that they will move after us (1)"
	await user_input
	await get_tree().process_frame
	current_step = TutorialStep.PROMPT_ABILITY
	finish_enemy_tutorial()
	
func promt_choosing_ability() -> void:
	if current_step != TutorialStep.PROMPT_ABILITY:
		return
	current_step = TutorialStep.SELECT_ABILITY
	prompt_text.text = "Select an ability"
	#continue_label.text = "(Click on ability to continue)"
	enable_mouse_for_canvas(ability_bar, true)

	# Highlight the entire ability bar.
	darken_ui.highlight_UI(ability_bar)
	
func _on_ability_selected(_ability: Ability) -> void:
	print("being called")
	if current_step != TutorialStep.SELECT_ABILITY:
		return
		
	print("passed")
	current_step = TutorialStep.CHOOSE_DIRECTION
	prompt_panel.show()
	prompt_text.text = "Select a direction"
	
func finish_enemy_tutorial() -> void:
	darken_ui.clear()
	prompt_panel.hide()
	task_panel.show()
	
func get_enemy() -> void:
	enemy = enemyParent.get_child(0)
	print(enemy)
	if enemy:
		enemy.being_hovered.connect(hover_enemy)

func enable_mouse_for_canvas(canvas:CanvasLayer, enable:bool) -> void:
	for control in canvas.get_children():
		if control is Control:
			(control as Control).mouse_behavior_recursive = (
			Control.MOUSE_BEHAVIOR_ENABLED if enable else Control.MOUSE_BEHAVIOR_DISABLED)
