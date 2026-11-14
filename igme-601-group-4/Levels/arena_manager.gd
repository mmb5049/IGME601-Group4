extends Node3D

@onready var enemyParent = $Enemies
@onready var obstacleParent = $Obstacles
@onready var gameOverScreen:GameOver = $GameOver

@export var onBoardMovement:bool;

@export_group("Arena Configuration")
@export var walls: Array[WallData] = []

var enemy_scene = preload("res://Characters/Enemy.tscn")
var wall_scene = preload("res://Arena Features/wall.tscn")
var wall_breakable_scene = preload("res://Arena Features/breakable_wall.tscn")
var enemies:Array[Enemy]
var total_enemies:int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	HexGrid.reset()
	
	gameOverScreen.restart_game.connect(func():get_tree().reload_current_scene())
	
	if enemyParent:
		spawn_enemy(Vector2i(1,1))
		spawn_enemy(Vector2i(3,-1))
		spawn_enemy(Vector2i(-2,-2))
		spawn_enemy(Vector2i(-4,3))
		
		
	spawn_walls()
	
	Global.player.health.died.connect(func():game_over(false))

func spawn_enemy(pos:Vector2i, type = enemy_scene):
	total_enemies += 1
	var new_enemy:Enemy = type.instantiate()
	enemyParent.add_child(new_enemy)
	new_enemy.movement.set_pos(pos)
	new_enemy.health.died.connect(enemy_died)
	enemies.push_back(new_enemy)
	
func spawn_walls() -> void:
	if not obstacleParent:
		return

	for wall_data in walls:
		var wall_type = wall_scene

		match wall_data.wall_type:
			WallData.WallType.NORMAL:
				wall_type = wall_scene

			WallData.WallType.BREAKABLE:
				wall_type = wall_breakable_scene

		spawn_obstacle(wall_data.position, wall_type)


func spawn_obstacle(pos:Vector2i, type = wall_scene):
	var new_obstacle:Obstacle = type.instantiate()
	obstacleParent.add_child(new_obstacle)
	new_obstacle.set_hex_position(pos)

func enemy_died():
	total_enemies -= 1
	if total_enemies <= 0:
		game_over(true)

func game_over(won:bool):
	if onBoardMovement == false:
		gameOverScreen.visible = true	
		gameOverScreen.win_screen.visible = won
		gameOverScreen.lose_screen.visible = not won
