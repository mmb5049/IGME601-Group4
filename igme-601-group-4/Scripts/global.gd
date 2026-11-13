extends Node

# typing this variable prevents the playerController script from compiling (godot is weird)
var player

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

enum EntityMask{
	NONE = 0,
	PLAYER = 1 << 0,
	ENEMY = 1 << 1,
	OBSTACLE = 1 << 2,
	ALL = 2 ** 3 - 1
}

# Bitshift is used to enable logical operators
enum OccupiedType {
	NONE = 0,
	STATIC = 1 << 0,
	DYNAMIC = 1 << 1
}

func has_flag(value, flag) -> bool:
	return (value & flag) == flag

func get_target_material(ability: Ability) -> ShaderMaterial:
	if ability.type == Global.AbilityType.MOVEMENT:
		return HexGrid.material_move
	return HexGrid.material_attack
