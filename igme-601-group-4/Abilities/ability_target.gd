extends RefCounted
class_name AbilityTarget

## A typed snapshot of the player's targeting choice. Queued abilities keep
## this object so direction and tile choices survive reordering in the UI.
var targeting_type: Global.TargetingType = Global.TargetingType.NONE
var is_valid: bool = false
var direction: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO


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
	return null
