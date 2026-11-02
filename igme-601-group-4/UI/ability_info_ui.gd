extends Control

class_name AbilityInfoUI

@onready var image:TextureRect = $TextureRect

var _ability:Ability = null

func hide_image(ability:Ability = null) -> void:
	if ability == null or _ability == ability:
		image.visible = false

func show_image() -> void:
	image.visible = true

func set_image(ability:Ability) -> void:
	image.texture = ability.info_card
	_ability = ability
