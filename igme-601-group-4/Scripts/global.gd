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
	HOLOGRAM = 1 << 3,
	ALL = 2 ** 4 - 1
}

# Bitshift is used to enable logical operators
enum OccupiedType {
	NONE = 0,
	STATIC = 1 << 0,
	DYNAMIC = 1 << 1
}

# returns true if _value has all flags in _flag
func contains_all_flags(_value, _flag) -> bool:
	return (_value & _flag) == _flag

# returns true if _value has any flag in _flag
func contains_a_flag(_value, _flag) -> bool:
	return (_value & _flag) != 0

func get_target_material(ability: Ability) -> ShaderMaterial:
	if ability.type == Global.AbilityType.MOVEMENT:
		return HexGrid.material_move
	return HexGrid.material_attack
