extends MeshInstance3D

class_name MeshManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func flash():
	set_instance_shader_parameter("is_flashing", true)
	await get_tree().create_timer(0.05).timeout
	set_instance_shader_parameter("is_flashing", false)
