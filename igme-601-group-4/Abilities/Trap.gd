extends Node3D
class_name Trap

var grid: Node3D
var cell: Vector2i
var damage_amount: int = 0
var triggered: bool = false


func setup(
	grid_reference: Node3D,
	grid_cell: Vector2i,
	trap_damage: int
) -> void:
	grid = grid_reference
	cell = grid_cell
	damage_amount = trap_damage


func trigger(target: Node) -> void:
	# A trap can only trigger once.
	if triggered:
		return

	triggered = true

	# Apply damage to the character stepping on the trap.
	if is_instance_valid(target) and target.has_method("damage"):
		target.damage(damage_amount)

	# Remove the trap from the grid.
	if is_instance_valid(grid):
		if grid.traps.get(cell) == self:
			grid.traps.erase(cell)

	# Destroy the trap scene.
	queue_free()
