extends CanvasLayer
class_name GameOver

@onready var win_screen:Control = $Win
@onready var lose_screen:Control = $Lose

signal restart_game
signal level_select

func _on_restart_button_pressed() -> void:
	restart_game.emit()

func _on_level_button_pressed() -> void:
	level_select.emit()
