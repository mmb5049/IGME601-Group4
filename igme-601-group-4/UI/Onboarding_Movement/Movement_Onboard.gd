
extends Node

enum TutorialStep {
	WELCOME,
	HOVER_ABILITY,
	ABILITY_DETAILS,
	SELECT_ABILITY,
	CHOOSE_DIRECTION,
	SHOW_QUEUE,
	HOVER_QUEUE,
	PRESS_START,
	PROMPT_MULTIPLE_ABILITY,
	COMPLETE
}

signal tutorial_complete(Vector2i)

@export var ability_bar: AbilityBarUI
@export var ability_sequence: AbilitySequenceUI
@export var ability_item_sequence: AbilitySequenceItemUI
@export var action_execute: ActionExecutionController
@export var ability_info_ui: CanvasLayer
@export var start_button:CanvasLayer
@export var darkenUI: DarkenUI

@onready var welcome_panel: PanelContainer = $Welcome
@onready var tutorial_panel: PanelContainer = $TutorialPrompt
@export var task_panel: PanelContainer
@onready var prompt_label: Label = $TutorialPrompt/TutorialText
@onready var continue_label: Label = $TutorialPrompt/TutorialText/ContinueText

var current_step: TutorialStep = TutorialStep.WELCOME

signal user_input

func _ready() -> void:
	ability_bar.ability_hovered.connect(_on_ability_hovered)
	ability_bar.ability_selected.connect(_on_ability_selected)
	ability_sequence.ability_confirmed.connect(_on_direction_selected)
	ability_sequence.child_entered_tree.connect(_on_sequence_child_added)
	action_execute.execution_started.connect(queue_in_action)
	action_execute.execution_finished.connect(prompt_multiple_ability)
	tutorial_complete.connect(HexGrid.set_tutorial_target)
	
	# Check existing descendants too, if necessary.
	_connect_to_existing_children(ability_sequence)
	
	# Welcome message
	ability_bar.visible = false
	enable_mouse_for_canvas(ability_bar, false)
	await user_input
	await get_tree().process_frame
	enable_mouse_for_canvas(ability_bar, true)
	welcome_panel.fade_in()
	welcome_panel.hide()
	
	# Begin ability tutorial
	start_ability_tutorial()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton:
		if event.is_released():
			return
	user_input.emit()

func start_ability_tutorial() -> void:
	current_step = TutorialStep.HOVER_ABILITY

	ability_bar.visible = true
	tutorial_panel.visible = true
	prompt_label.text = "Hover over an ability to learn more!"
	prompt_label.show()
	continue_label.text = "(Hover to continue)"

	# Highlight the entire ability bar.
	darkenUI.highlight_UI(ability_bar)


func _on_ability_hovered(_ability: Ability = null, _slot: Control = null) -> void:
	if current_step != TutorialStep.HOVER_ABILITY:
		return
	current_step = TutorialStep.ABILITY_DETAILS
	if ability_bar.is_hovered:
		print("Already hovered")
		ability_bar.hovered_slot._on_mouse_entered()
	ability_bar.set_click_enabled(false)

	# Wait for AbilityInfoUI to finish updating its visibility/layout.
	await get_tree().process_frame

	prompt_label.text = "The full details of the ability will display here!"
	continue_label.text = "(Click to continue)"

	# Move the highlight to the ability information panel.
	darkenUI.highlight_UI(ability_info_ui)
	await user_input
	await get_tree().process_frame
	ability_bar.set_click_enabled(true)
	
	promt_choosing_ability()
	
func promt_choosing_ability() -> void:
	if current_step != TutorialStep.ABILITY_DETAILS:
		return
	current_step = TutorialStep.SELECT_ABILITY
	prompt_label.text = "Select an ability"
	continue_label.text = "(Click on ability to continue)"
	enable_mouse_for_canvas(ability_bar, true)

	# Highlight the entire ability bar.
	darkenUI.highlight_UI(ability_bar)

func _on_ability_selected(_ability: Ability) -> void:
	if current_step != TutorialStep.SELECT_ABILITY:
		return
	current_step = TutorialStep.CHOOSE_DIRECTION
	darkenUI.clear()
	prompt_label.text = "Select a direction"
	continue_label.text = "(Click on grid to continue)"

func _on_direction_selected() -> void:
	if current_step != TutorialStep.CHOOSE_DIRECTION:
		return
	show_queue()

func show_queue () -> void:
	if current_step != TutorialStep.CHOOSE_DIRECTION:
		return
	current_step = TutorialStep.SHOW_QUEUE
	
	# Highlight queue
	darkenUI.highlight_UI(ability_sequence)
	prompt_label.text = "The ability got added to queue"
	continue_label.text = "(Click to continue)"
	
	await get_tree().process_frame
	await user_input
	prompt_hover_queue()
	
func prompt_hover_queue () -> void:
	if current_step != TutorialStep.SHOW_QUEUE:
		return
	current_step = TutorialStep.HOVER_QUEUE
	prompt_label.text = "Hover over ability to show a preview"
	continue_label.text = "(Hover to continue)"
	enable_mouse_for_canvas(start_button,false)
	
func prompt_press_start () -> void:
	if current_step != TutorialStep.HOVER_QUEUE:
		return
	current_step = TutorialStep.PRESS_START
	prompt_label.text = "Press start to execute the queue"
	continue_label.text = "(Click on button to continue)"
	# Highlight start button
	darkenUI.highlight_UI(start_button)
	enable_mouse_for_canvas(start_button,true)
	
func queue_in_action() -> void:
	if current_step != TutorialStep.PRESS_START:
		return
	darkenUI.clear()
	tutorial_panel.hide()
	
func prompt_multiple_ability() -> void:
	if current_step != TutorialStep.PRESS_START:
		return
	current_step = TutorialStep.PROMPT_MULTIPLE_ABILITY
	prompt_label.text = "You can add multiple abilities to the queue before executing it!"
	continue_label.text = "(Click to continue)"
	tutorial_panel.show()
	await user_input
	complete_ability_tutorial()

func complete_ability_tutorial() -> void:
	current_step = TutorialStep.COMPLETE

	tutorial_panel.hide()
	darkenUI.clear()

	print("Ability tutorial completed!")
	if Global.player.movement.current_cell == Vector2i(2,2):
		tutorial_complete.emit(Vector2i(-2,-2))
	else:
		tutorial_complete.emit(Vector2i(2,2))
	task_panel.show()

func _on_sequence_child_added(child: Node) -> void:

	# Monitor future children.
	if not child.child_entered_tree.is_connected(_on_sequence_child_added):
		child.child_entered_tree.connect(_on_sequence_child_added)

	# Check children that already exist.
	for existing_child in child.get_children():
		_on_sequence_child_added(existing_child)

	if child is AbilitySequenceItemUI:
		if not child.preview_character.is_connected(_on_preview_character):
			child.preview_character.connect(_on_preview_character)


func _connect_to_existing_children(parent: Node) -> void:
	for child in parent.get_children():
		_on_sequence_child_added(child)


func _on_preview_character() -> void:
	
	if current_step != TutorialStep.HOVER_QUEUE:
		return
	darkenUI.clear()
	prompt_press_start()

func enable_mouse_for_canvas(canvas:CanvasLayer, enable:bool) -> void:
	for control in canvas.get_children():
		if control is Control:
			(control as Control).mouse_behavior_recursive = (
			Control.MOUSE_BEHAVIOR_ENABLED if enable else Control.MOUSE_BEHAVIOR_DISABLED)
