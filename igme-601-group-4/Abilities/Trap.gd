
extends Node3D
class_name Trap

var grid: Node3D
var cell: Vector2i
var damage_amount: int = 0
var triggered: bool = false

@export var spawn_height: float = 1.5
@export var spawn_duration: float = 0.4
@export var rotation_amount: float = 25.0

var is_spawning: bool = true
var explosion_scene: PackedScene = preload(
	"res://VFX/Trap_Explode.tscn"
)

func setup(
	grid_reference: Node3D,
	grid_cell: Vector2i,
	trap_damage: int
) -> void:
	grid = grid_reference
	cell = grid_cell
	damage_amount = trap_damage


func play_spawn_animation() -> void:
	var target_position: Vector3 = global_position

	# Start above the tile.
	global_position = target_position + Vector3.UP * spawn_height

	# Start slightly tilted.
	rotation_degrees.x = -rotation_amount
	rotation_degrees.z = rotation_amount

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"global_position",
		target_position,
		spawn_duration
	)

	tween.tween_property(
		self,
		"rotation_degrees",
		Vector3.ZERO,
		spawn_duration
	)

	await tween.finished

	is_spawning = false

	# Check occupancy only after the trap lands.
	if is_instance_valid(grid):
		if grid.is_occupied(cell):
			var occupant: Node = grid.occupied_cells.get(cell)
			if is_instance_valid(occupant):
				trigger(occupant)


func trigger(target: Node) -> void:
	if triggered or is_spawning:
		return

	triggered = true

	# Spawn the explosion at the trap's position.
	var explosion = explosion_scene.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position

	# Play all particle effects.
	for child in explosion.get_children():
		if child is GPUParticles3D:
			child.emitting = true

	# Damage the character.
	if is_instance_valid(target) and target.has_method("damage"):
		target.damage(damage_amount)

	# Remove the trap from the grid.
	if is_instance_valid(grid):
		if grid.traps.get(cell) == self:
			grid.traps.erase(cell)

	# Remove the trap, not the explosion.
	queue_free()
