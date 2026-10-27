extends Node3D

func _ready() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true

			# Wait for each particle system to finish.
			await child.finished

	# Free the explosion once all particle effects finish.
	queue_free()
