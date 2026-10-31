extends AbilityPresentation
class_name WhirlwindPresentation

const RUNNER := preload("res://Abilities/Presentation/presentation_motion.gd")

@export_range(0.1, 2.0, 0.01, "suffix:s") var duration: float = 0.48


func play(actor: Node3D, visual: Node3D, target: AbilityTarget) -> bool:
	if not is_instance_valid(visual) or target.targeting_type != Global.TargetingType.ANNULAR:
		return false
	var route := build_route(actor, visual, target)
	if route.size() < 3:
		return false
	var runner := RUNNER.new()
	actor.add_child(runner)
	var completed: bool = await runner.play(actor, visual, route, duration)
	if is_instance_valid(runner):
		runner.queue_free()
	return completed


func build_route(actor: Node3D, visual: Node3D, target: AbilityTarget) -> PackedVector3Array:
	var origin: Vector3 = visual.global_position
	var route := PackedVector3Array([origin])
	var cells: Array[Vector2i] = target.resolve_cells(actor.movement.current_cell)
	for cell in cells:
		var point: Vector3 = HexGrid.to_global(HexGrid.hex_to_world(cell))
		point.y = origin.y
		route.append(point)
	# Complete rings close the circuit; clipped edge rings visit valid tiles
	# in ring order and return directly, without visiting off-board tiles.
	if not cells.is_empty():
		if cells.size() == 6 * target.ring_radius:
			route.append(route[1])
		route.append(origin)
	return route
