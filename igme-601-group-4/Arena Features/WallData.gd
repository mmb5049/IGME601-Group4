extends Resource
class_name WallData

@export var position: Vector2i = Vector2i.ZERO

enum WallType {
	NORMAL,
	BREAKABLE
}

@export var wall_type: WallType = WallType.NORMAL
