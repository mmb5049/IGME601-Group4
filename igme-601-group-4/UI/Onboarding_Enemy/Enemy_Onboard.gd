extends Node

enum TutorialStep {
	SHOW_ENEMY,
	PROMP_HOVER,
	HOVER_ENEMY,
	PROMPT_ABILITY,
	SELECT_ABILITY,
	SHOW_ENEMY_PREVIEW,
	FINISHED
}

var current_step: TutorialStep = TutorialStep.SHOW_ENEMY

@export var ability_bar: AbilityBarUI
@export var ability_sequence: AbilitySequenceUI
@export var darken_ui:DarkenUI
@onready var welcome_panel: PanelContainer = $Welcome
@onready var prompt_panel:PanelContainer = $TutorialPrompt
@onready var prompt_text:Label = $TutorialPrompt/TutorialText
@onready var continue_label: Label = $TutorialPrompt/TutorialText/ContinueText
@export var enemyParent:Node
@export var enemy:Enemy
@export var task_panel: PanelContainer
var ability_chosen: int = 2

signal user_input

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ability_bar.visible = false
	ability_sequence.ability_confirmed.connect(_on_ability_confirmed)
	ability_bar.ability_selected.connect(_on_show_enemy_preview)
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
	continue_label.text = "(Click to continue)"
	await user_input
	await get_tree().process_frame
	
	current_step = TutorialStep.PROMP_HOVER
	prompt_hover()

func prompt_hover()-> void:
	if current_step != TutorialStep.PROMP_HOVER:
		return
	prompt_text.text = "Hover over the enemy to learn more!"
	continue_label.text = "(Hover to continue)"
	darken_ui.clear()
	current_step = TutorialStep.HOVER_ENEMY
	
func hover_enemy() -> void:
	if current_step != TutorialStep.HOVER_ENEMY:
		return
	
	prompt_text.text = "Enemy have their own ability queue \n And the number 2 mean that they will move after us (1)"
	continue_label.text = "(Click to continue)"
	await user_input
	await get_tree().process_frame
	current_step = TutorialStep.PROMPT_ABILITY
	prompt_choosing_ability()
	
func prompt_choosing_ability() -> void:
	if current_step != TutorialStep.PROMPT_ABILITY:
		return
	current_step = TutorialStep.SELECT_ABILITY
	prompt_text.text = "Select an ability (%d)" %ability_chosen
	continue_label.text = "(Click on ability to continue)"
	ability_bar.visible = true
	#continue_label.text = "(Click on ability to continue)"
	enable_mouse_for_canvas(ability_bar, true)

	# Highlight the entire ability bar.
	darken_ui.highlight_UI(ability_bar)
	
func _on_ability_confirmed() -> void:
	if current_step != TutorialStep.SELECT_ABILITY:
		return
	
	ability_chosen -= 1
	prompt_text.text = "Select an ability (%d)" %ability_chosen
		
	if ability_chosen > 2:
		return
	current_step = TutorialStep.SHOW_ENEMY_PREVIEW
	
func _on_show_enemy_preview(_ability: Ability) -> void:
	print("After Step: ", current_step)
	if current_step != TutorialStep.SHOW_ENEMY_PREVIEW:
		return
		
	prompt_text.text = "You can also see the preview of the enemy"
	continue_label.text = "(Click to continue)"
	darken_ui.highlight_3D(enemy)
	await user_input
	await get_tree().process_frame
	current_step = TutorialStep.FINISHED
	finish_enemy_tutorial()
	
func finish_enemy_tutorial() -> void:
	darken_ui.clear()
	prompt_panel.hide()
	task_panel.show()
	
func get_enemy() -> void:
	enemy = enemyParent.get_child(0)
	if enemy:
		enemy.being_hovered.connect(hover_enemy)

func enable_mouse_for_canvas(canvas:CanvasLayer, enable:bool) -> void:
	for control in canvas.get_children():
		if control is Control:
			(control as Control).mouse_behavior_recursive = (
			Control.MOUSE_BEHAVIOR_ENABLED if enable else Control.MOUSE_BEHAVIOR_DISABLED)
			
func disable_mouse_for_canvas(canvas:CanvasLayer, enable:bool) -> void:
	for control in canvas.get_children():
		if control is Control:
			(control as Control).mouse_behavior_recursive = (
			Control.MOUSE_BEHAVIOR_DISABLED if enable else Control.MOUSE_BEHAVIOR_ENABLED)			
