extends Resource
class_name Ability

enum AbilityType {
	MOVEMENT,
	ATTACK,
	TRAP,
	STATUS,
	DEFENSE
}

enum TargetingType {
	NONE,
	DIRECTION,
	AREA,
	SINGLE_TILE
}

@export_category("Basic Information")
@export var ability_name: String = ""

@export_category("Ability Properties")
@export var type: AbilityType = AbilityType.ATTACK
@export var cost: int = 0
@export var cooldown: float = 0.0
@export var range: int = 0

@export_category("Targeting")
@export var targeting_type: TargetingType = TargetingType.NONE

@export_category("Shape")
@export var shape: Array[Vector2i] = []
