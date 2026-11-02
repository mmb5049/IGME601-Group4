extends Node3D

class_name AnimationManager

@onready var animationPlayer:AnimationPlayer = $AnimationPlayer
@export var idle_animation:Animation

signal take_action()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func has_animation(animation:Animation) -> bool:
	var return_value:bool = false
	if animation and animationPlayer:
		for anim_name in animationPlayer.get_animation_list():
			var anim:Animation = animationPlayer.get_animation(anim_name)
			if anim and anim.resource_path == animation.resource_path:
				return_value = true
				break
	return return_value

func play_animation(animation:Animation):
	if animation and animationPlayer:
		for anim_name in animationPlayer.get_animation_list():
			var anim:Animation = animationPlayer.get_animation(anim_name)
			if anim and anim.resource_path == animation.resource_path:
				animationPlayer.play(anim_name)
				break

# called when the animation has reached a keyframe where an action should be called
func on_animation_action():
	take_action.emit()
