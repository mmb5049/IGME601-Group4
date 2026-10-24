extends Node3D

@onready var num_label:Label3D = $Label3D
var speed:Vector3 = Vector3(0,1,0)
var font_speed:float = 2.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var animationPlayer:AnimationPlayer = $AnimationPlayer
	animationPlayer.animation_finished.connect(destroy)
	pass

func set_number(num:int):
	num_label.text = str(num)

func destroy(_argument):
	queue_free()
