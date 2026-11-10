extends Node

@onready var welcomePanel : PanelContainer = $Welcome
@export var darkenUI : ColorRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	welcomePanel.fade_in()
	darkenUI.ChangeSize()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
