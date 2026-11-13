extends Character

class_name Hologram

# Hologram keeps track of health and movement during queue preview
# with it's own nodes

@export var parent:Character

func reset() -> void:
	health.copy(parent.health)
	
func execute_queued_ability(entry: QueuedAbility) -> bool:
	var ability:Ability = entry.ability
	var target:AbilityTarget = entry.target
	var succeeded:bool = false
	
	match ability.type:
		Global.AbilityType.MOVEMENT: 
			movement.set_pos(movement.get_destination(ability,target,movement.current_cell),false)

		Global.AbilityType.ATTACK:
			_attack_ability = ability
			_attack_target = target
			_attack_applied = false
			_apply_attack()
			_attack_ability = null
			_attack_target = null
		
		Global.AbilityType.TRAP:
			succeeded = false
			for trap_cell: Vector2i in target.resolve_cells(movement.current_cell):
				if not HexGrid.traps.has(trap_cell):
					if HexGrid.place_trap(trap_cell, ability.damage):
						succeeded = true
		Global.AbilityType.STATUS:
			activate_self_enhance()
