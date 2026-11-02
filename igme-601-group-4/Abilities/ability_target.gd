extends RefCounted
class_name AbilityTarget

## A typed snapshot of the player's targeting choice. Queued abilities keep
## this object so direction and tile choices survive reordering in the UI.
var targeting_type: Global.TargetingType = Global.TargetingType.NONE
var is_valid: bool = false
var direction: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
## Annular targets save a complete ring relative to the actor, just like
## SINGLE_TILE saves a relative offset. Reordering/movement retains the choice.
var ring_radius: int = 0
var target_cells: Array[Vector2i] = []


func _init(new_targeting_type: Global.TargetingType = Global.TargetingType.NONE) -> void:
	targeting_type = new_targeting_type


## Converts the typed target back to the value expected by the group's current
## execute_ability implementation.
func get_execution_data() -> Variant:
	match targeting_type:
		Global.TargetingType.NONE:
			return null
		Global.TargetingType.DIRECTION:
			return direction
		Global.TargetingType.SINGLE_TILE:
			return target_cell
		Global.TargetingType.SHAPE:
			return target_cell
		Global.TargetingType.ANNULAR:
			return target_cells.duplicate()
	return null


func resolve_cells(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var offsets: Array[Vector2i] = []
	if targeting_type == Global.TargetingType.ANNULAR:
		offsets.append_array(target_cells)
	else:
		offsets.append(target_cell)
	for offset in offsets:
		var cell: Vector2i = origin + offset
		if HexGrid.is_valid_cell(cell) and not cells.has(cell):
			cells.append(cell)
	return cells
