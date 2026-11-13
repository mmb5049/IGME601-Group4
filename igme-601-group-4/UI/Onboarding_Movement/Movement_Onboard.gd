
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
@export var ability_info_ui: Control
@export var darkenUI: ColorRect

@onready var welcome_panel: PanelContainer = $Welcome
@onready var tutorial_panel: PanelContainer = $TutorialPrompt
@export var task_panel: PanelContainer
@onready var prompt_label: Label = $TutorialPrompt/TutorialText

var current_step: TutorialStep = TutorialStep.WELCOME


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

	##ability_sequence.queue
	# Welcome message
	await get_tree().create_timer(2.0).timeout
	welcome_panel.fade_in()

	# Wait for the welcome message to finish displaying.
	await get_tree().create_timer(3.0).timeout

	welcome_panel.hide()

	# Begin ability tutorial
	start_ability_tutorial()


func start_ability_tutorial() -> void:
	current_step = TutorialStep.HOVER_ABILITY

	darkenUI.show()
	tutorial_panel.visible = true
	prompt_label.text = "Hover over an ability to learn more!"
	prompt_label.show()

	# Highlight the entire ability bar.
	darkenUI.ChangeSize(Vector2 (800,200), Vector2 (950,1000))


func _on_ability_hovered(ability: Ability, slot: Control) -> void:
	if current_step != TutorialStep.HOVER_ABILITY:
		return
	current_step = TutorialStep.ABILITY_DETAILS

	# Wait for AbilityInfoUI to finish updating its visibility/layout.
	await get_tree().process_frame

	prompt_label.text = "The full details of the game will display here!"

	# Move the highlight to the ability information panel.
	darkenUI.ChangeSize(Vector2 (650,1250), Vector2 (1650,100))
	await get_tree().create_timer(5.0).timeout
	promt_choosing_ability()
	
func promt_choosing_ability() -> void:
	if current_step != TutorialStep.ABILITY_DETAILS:
		return
	current_step = TutorialStep.SELECT_ABILITY
	prompt_label.text = "Select the ability"

	# Highlight the entire ability bar.
	darkenUI.ChangeSize(Vector2 (800,200), Vector2 (950,1000))

func _on_ability_selected(ability: Ability) -> void:
	if current_step != TutorialStep.SELECT_ABILITY:
		return
	current_step = TutorialStep.CHOOSE_DIRECTION
	darkenUI.hide()
	prompt_label.text = "Select the direction"

func _on_direction_selected() -> void:
	if current_step != TutorialStep.CHOOSE_DIRECTION:
		return
	darkenUI.show()
	show_queue()

func show_queue () -> void:
	if current_step != TutorialStep.CHOOSE_DIRECTION:
		return
	current_step = TutorialStep.SHOW_QUEUE
	darkenUI.ChangeSize(Vector2 (200,1250), Vector2 (40,10))
	prompt_label.text = "Ability got added to queue"
	await get_tree().create_timer(4.0).timeout
	prompt_hover_queue()
	
func prompt_hover_queue () -> void:
	if current_step != TutorialStep.SHOW_QUEUE:
		return
	current_step = TutorialStep.HOVER_QUEUE
	prompt_label.text = "Hover over ability to show where the player will be"
	
func prompt_press_start () -> void:
	if current_step != TutorialStep.HOVER_QUEUE:
		return
	await get_tree().create_timer(3.0).timeout
	darkenUI.show()
	current_step = TutorialStep.PRESS_START
	prompt_label.text = "Press start to execute the queue"
	darkenUI.ChangeSize(Vector2 (200,200), Vector2 (175,950))
	
func queue_in_action() -> void:
	if current_step != TutorialStep.PRESS_START:
		return
	darkenUI.hide()
	tutorial_panel.hide()
	
func prompt_multiple_ability() -> void:
	if current_step != TutorialStep.PRESS_START:
		return
	current_step = TutorialStep.PROMPT_MULTIPLE_ABILITY
	prompt_label.text = "You can add multiple ability to the queue before execute it!"
	tutorial_panel.show()
	await get_tree().create_timer(4.0).timeout
	complete_ability_tutorial()

func complete_ability_tutorial() -> void:
	current_step = TutorialStep.COMPLETE

	tutorial_panel.hide()
	darkenUI.hide()

	print("Ability tutorial completed!")
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
		print("Ability item found!")

		if not child.preview_character.is_connected(_on_preview_character):
			child.preview_character.connect(_on_preview_character)


func _connect_to_existing_children(parent: Node) -> void:
	for child in parent.get_children():
		_on_sequence_child_added(child)


func _on_preview_character() -> void:
	print("Character preview signal received!")
	
	if current_step != TutorialStep.HOVER_QUEUE:
		return
	darkenUI.hide()
	prompt_press_start()
