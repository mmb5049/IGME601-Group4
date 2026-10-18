extends RefCounted
class_name QueuedAbility

## Unique ID distinguishes repeated uses of the same Ability resource.
var id: int
var ability: Ability
var target: AbilityTarget


func _init(
	new_id: int = 0,
	new_ability: Ability = null,
	new_target: AbilityTarget = null
) -> void:
	id = new_id
	ability = new_ability
	target = new_target
