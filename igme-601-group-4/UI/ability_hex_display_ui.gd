extends Node2D
class_name AbilityHexDisplayUI

## Pure visual component shared by selectable Bar Slots and queued items.
## Interaction belongs to the parent component, not to this display.
@export var ability: Ability
## Optional icon for non-Ability controls that share the same hexagon visual,
## such as the execution button. Ability icons remain the default source.
@export var icon_override: Texture2D
@export var frame_color: Color = Color(0.2346074, 0.5845947, 1.0, 0.6784314)

@onready var _ability_icon: TextureRect = %AbilityIcon


func _ready() -> void:
	_refresh_display()


func set_ability(new_ability: Ability) -> void:
	ability = new_ability
	_refresh_display()


func set_icon(new_icon: Texture2D) -> void:
	icon_override = new_icon
	_refresh_display()


func set_frame_color(new_color: Color) -> void:
	frame_color = new_color
	_refresh_display()


func _refresh_display() -> void:
	if not is_node_ready():
		return

	_ability_icon.texture = icon_override if icon_override else (ability.icon if ability else null)
	$VisualContent/HexFrame.self_modulate = frame_color
