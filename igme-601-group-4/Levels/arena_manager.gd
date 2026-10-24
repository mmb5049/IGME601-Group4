extends Node3D

@onready var enemyParent = $Enemies
@onready var gameOverScreen = $GameOver
var enemyScene = preload("res://Characters/Enemy.tscn")
var enemies:Array[Enemy]
var total_enemies:int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_enemy(Vector2i(1,1))
	spawn_enemy(Vector2i(3,-1))
	spawn_enemy(Vector2i(-2,-2))
	spawn_enemy(Vector2i(-4,3))

func spawn_enemy(pos:Vector2i):
	total_enemies += 1
	var new_enemy:Enemy = enemyScene.instantiate()
	enemyParent.add_child(new_enemy)
	new_enemy.movement.set_pos(pos)
	new_enemy.died.connect(enemy_died)
	enemies.push_back(new_enemy)

func enemy_died():
	total_enemies -= 1
	if total_enemies <= 0:
		game_over()

func game_over():
	gameOverScreen.visible = true
