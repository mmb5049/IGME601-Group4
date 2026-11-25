extends Character

class_name Hologram

# Hologram keeps track of health and movement during queue preview
# with it's own nodes

@export var parent:Entity
func _ready() -> void:
	if(health):
		health.died.connect(died)
		parent.health.died.connect(died)
		
		# Update health bar during preview
		if parent is Enemy:
			await parent.ready
			health.changed.connect(
				func(_current,_max):
					(parent as Enemy)._health_bar._update_health(_current,_max,false)
			)

func reset() -> void:
	@warning_ignore("int_as_enum_without_cast")
	entity_type = Global.EntityMask.HOLOGRAM | parent.entity_type
	if(movement):
		movement.copy(parent.movement)
	if(health):
		health.copy(parent.health)
	if(parent is Character):
		self_enhance_stacks = parent.self_enhance_stacks
		ability_queue.copy(parent.ability_queue)
		attack_mask = parent.attack_mask | Global.EntityMask.HOLOGRAM

func execute_queued_ability(entry: QueuedAbility) -> bool:
	var ability:Ability = entry.ability
	var target:AbilityTarget = entry.target
	var succeeded:bool = false
	
	match ability.type:
		Global.AbilityType.MOVEMENT: 
			movement.set_pos(movement.get_destination(ability,target,movement.current_cell),true)

		Global.AbilityType.ATTACK:
			_apply_attack(entry.ability,entry.target,0,attack_mask,true)
		
		Global.AbilityType.TRAP:
			# Trap placement belongs to live execution.
			pass
		Global.AbilityType.STATUS:
			activate_self_enhance()
	return succeeded

func died() -> void:
	visible = false
	if parent is Enemy:
		(parent as Enemy).user_interface.hide_ui()
	HexGrid.set_occupied_preview(movement.current_cell,false)
