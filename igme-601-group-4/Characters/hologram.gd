extends Character

class_name Hologram

# Hologram keeps track of health and movement during queue preview
# with it's own nodes

@export var parent:Character

func reset() -> void:
	entity_type = Global.EntityMask.HOLOGRAM | parent.entity_type
	movement.copy(parent.movement)
	health.copy(parent.health)
	ability_queue.copy(parent.ability_queue)

func execute_queued_ability(entry: QueuedAbility) -> bool:
	var ability:Ability = entry.ability
	var target:AbilityTarget = entry.target
	var succeeded:bool = false
	
	match ability.type:
		Global.AbilityType.MOVEMENT: 
			movement.set_pos(movement.get_destination(ability,target,movement.current_cell),true)

		Global.AbilityType.ATTACK:
			_apply_attack(entry.ability,entry.target,0,Global.EntityMask.HOLOGRAM)
		
		Global.AbilityType.TRAP:
			# TODO: Implement traps for preview
			succeeded = false
			for trap_cell: Vector2i in target.resolve_cells(movement.current_cell):
				if not HexGrid.traps.has(trap_cell):
					if HexGrid.place_trap(trap_cell, ability.damage):
						succeeded = true
		Global.AbilityType.STATUS:
			activate_self_enhance()
	return succeeded
