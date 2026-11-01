extends Node
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
	SHAPE,
	SINGLE_TILE,
	ANNULAR
}

# Bitshift is used to enable logical operators
enum OccupiedType {
	NONE = 0,
	STATIC = 1 << 0,
	DYNAMIC = 1 << 1
}

func has_flag(value, flag) -> bool:
	return (value & flag) == flag
