extends Entity

class_name Character

@export var movement:CharacterMovement
@export var health:Health
@export var hologram:Hologram

var number_display = preload("res://Misc/number_display.tscn")

var ability_queue: AbilityQueue = AbilityQueue.new()

var self_enhance_stacks: int = 0
const SELF_ENHANCE_MULTIPLIER: float = 1.5

func activate_self_enhance() -> void:
	# Every activation adds another stack.
	self_enhance_stacks += 1

func execute_queued_ability(_entry: QueuedAbility) -> bool:
	return false

## Connected to AnimationManager.take_action, and also called directly as a fallback.
# Deals damage based on ability and target. Enter a character_mask to only 
# damage entities with that flag
func _apply_attack(ability:Ability, target:AbilityTarget, _action_num:int = 0, 
character_mask:Global.EntityMask = Global.EntityMask.ALL, use_preview = false) -> void:
	# action_num is for attacks triggered by animations.
	# if we want to deal damage multiple times in one ability,
	# this number signifies the index of which attack it is

	# Calculate damage
	var final_damage: int = ability.damage
	if self_enhance_stacks > 0:
		var multiplier: float = pow(SELF_ENHANCE_MULTIPLIER, self_enhance_stacks)
		final_damage = roundi(final_damage * multiplier)
	
	# Apply damage
	for target_cell: Vector2i in target.resolve_cells(movement.current_cell):
		var victim: Variant = null
		if not use_preview:
			HexGrid.occupied_cells.get(target_cell)
		else:
			HexGrid.occupied_cells_preview.get(target_cell)
		if (is_instance_valid(victim) and victim.health and not victim.is_queued_for_deletion() 
		and Global.contains_a_flag(character_mask,victim.entity_type)):
			victim.health.damage(final_damage)
		else:
			var new_display: Node3D = number_display.instantiate()
			get_parent().add_child(new_display)
			new_display.global_position = HexGrid.hex_to_world(target_cell) + Vector3(0, 0.5, 0)
			new_display.set_number(0)
