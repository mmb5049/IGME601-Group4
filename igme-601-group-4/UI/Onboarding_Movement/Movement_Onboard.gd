
extends Node

enum TutorialStep {
	WELCOME,
	HOVER_ABILITY,
	SELECT_ABILITY,
	COMPLETE
}

@export var ability_bar: AbilityBarUI
@export var ability_info_ui: Control
@export var darkenUI: ColorRect

@onready var welcome_panel: PanelContainer = $Welcome
@onready var tutorial_panel: PanelContainer = $TutorialPrompt
@onready var prompt_label: Label = $TutorialPrompt/TutorialText

var current_step: TutorialStep = TutorialStep.WELCOME


func _ready() -> void:
	ability_bar.ability_hovered.connect(_on_ability_hovered)
	ability_bar.ability_selected.connect(_on_ability_selected)

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

	current_step = TutorialStep.SELECT_ABILITY

	# Wait for AbilityInfoUI to finish updating its visibility/layout.
	await get_tree().process_frame

	prompt_label.text = "The full details of the game will display here!"

	# Move the highlight to the ability information panel.
	darkenUI.ChangeSize(Vector2 (650,1250), Vector2 (1650,100))
	await get_tree().create_timer(2.0).timeout
	
func promt_choosing_ability() -> void:
	## placeholder for now
	current_step = TutorialStep.SELECT_ABILITY

func _on_ability_selected(ability: Ability) -> void:
	if current_step != TutorialStep.SELECT_ABILITY:
		return

	complete_ability_tutorial()


func complete_ability_tutorial() -> void:
	current_step = TutorialStep.COMPLETE

	prompt_label.hide()
	darkenUI.hide()

	print("Ability tutorial completed!")
