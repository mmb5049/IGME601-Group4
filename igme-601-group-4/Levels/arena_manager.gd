extends Node3D

@onready var enemyParent = $Enemies
var enemyScene = preload("res://Characters/Enemy.tscn")
var enemies:Array[Enemy]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_enemy(Vector2i(2,1))

func spawn_enemy(pos:Vector2i):
	var new_enemy:Enemy = enemyScene.instantiate()
	enemyParent.add_child(new_enemy)
	new_enemy.set_grid_pos(pos)
	enemies.push_back(new_enemy)
