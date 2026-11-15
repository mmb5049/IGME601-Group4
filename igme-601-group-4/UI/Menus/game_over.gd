extends Control
class_name GameOver

@onready var win_screen:Control = $Win
@onready var lose_screen:Control = $Lose

signal restart_game

func _on_button_pressed() -> void:
	restart_game.emit()
