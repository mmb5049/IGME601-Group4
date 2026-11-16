extends Node3D

@onready var enemyParent = get_node_or_null("Enemies")
@onready var obstacleParent = get_node_or_null("Obstacles")
@onready var gameOverScreen: GameOver = get_node_or_null(
	"%GameOver" if has_node("%GameOver") else "GameOver"
) as GameOver
@export var onBoardMovement:bool;

@export_group("Arena Configuration")
@export_file("*.json") var levels_file: String = "res://Levels/Levels_Data.json"
@export var currentLevel: int

var current_level_data: Dictionary = {}
@export var walls: Array[WallData] = []


var enemy_scene = preload("res://Characters/Enemy.tscn")
var wall_scene = preload("res://Arena Features/Wall.tscn")
var wall_breakable_scene = preload("res://Arena Features/breakable_wall.tscn")
var enemies:Array[Enemy]
var total_enemies:int = 0

@export var player_start:Vector2i = Vector2i.MIN

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	HexGrid.reset()
	
	if player_start != Vector2i.MIN:
		Global.player.movement.set_pos(player_start)
	
	if gameOverScreen:
		gameOverScreen.restart_game.connect(func(): get_tree().reload_current_scene())

	if not onBoardMovement and currentLevel > 0:
		load_level_data()
		if not current_level_data.is_empty():
			spawn_level_contents()
	else:
		# Tutorials and the original Arena do not use numbered JSON layouts.
		if enemyParent:
			spawn_enemy(Vector2i(1,1))
			spawn_enemy(Vector2i(3,-1))
			spawn_enemy(Vector2i(-2,-2))
			spawn_enemy(Vector2i(-4,3))
		if onBoardMovement:
			spawn_walls()
		elif obstacleParent:
			spawn_obstacle(Vector2i(-1, -1))
			spawn_obstacle(Vector2i(0, -1))
			spawn_obstacle(Vector2i(1, -1))
			spawn_obstacle(Vector2i(-2, 0), wall_breakable_scene)
			spawn_obstacle(Vector2i(-3, 1), wall_breakable_scene)
			spawn_obstacle(Vector2i(-3, 2), wall_breakable_scene)

	Global.player.health.died.connect(func(): game_over(false))

func spawn_enemy(pos:Vector2i, type = enemy_scene):
	total_enemies += 1
	var new_enemy:Enemy = type.instantiate()
	enemyParent.add_child(new_enemy)
	new_enemy.movement.set_pos(pos)
	new_enemy.death_animation_finished.connect(enemy_died)
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
	new_obstacle.movement.set_pos(pos)

func enemy_died():
	total_enemies -= 1
	if total_enemies == 0 and gameOverScreen != null and not gameOverScreen.visible:
		game_over(true)

func game_over(won:bool):
	if not onBoardMovement and gameOverScreen != null:
		gameOverScreen.visible = true
		gameOverScreen.win_screen.visible = won
		gameOverScreen.lose_screen.visible = not won

func load_level_data() -> void:
	if not FileAccess.file_exists(levels_file):
		push_error("Levels file not found: " + levels_file)
		return

	var file = FileAccess.open(levels_file, FileAccess.READ)
	var parsed_data = JSON.parse_string(file.get_as_text())

	if parsed_data == null or not parsed_data is Dictionary:
		push_error("Invalid levels JSON!")
		return

	var all_levels: Array = parsed_data.get("levels", [])

	for level in all_levels:
		if int(level.get("level_number", -1)) == currentLevel:
			current_level_data = level
			print("Loaded Level: ", level.get("level_name", "Unnamed"))
			return

	push_error("Level %d was not found!" % currentLevel)
	
func spawn_level_contents() -> void:
	# Spawn enemies
	if enemyParent:
		for enemy_data in current_level_data.get("enemies", []):
			var pos_data: Array = enemy_data.get("position", [])

			if pos_data.size() != 2:
				continue

			var pos = Vector2i(
				int(pos_data[0]),
				int(pos_data[1])
			)

			spawn_enemy(pos)

	# Spawn walls
	if obstacleParent:
		for wall_data in current_level_data.get("walls", []):
			var pos_data: Array = wall_data.get("position", [])

			if pos_data.size() != 2:
				continue

			var pos = Vector2i(
				int(pos_data[0]),
				int(pos_data[1])
			)

			var wall_type = wall_scene

			match str(wall_data.get("type", "NORMAL")).to_upper():
				"NORMAL":
					wall_type = wall_scene

				"BREAKABLE":
					wall_type = wall_breakable_scene

				_:
					push_warning("Unknown wall type!")

			spawn_obstacle(pos, wall_type)


func _on_game_over_visibility_changed() -> void:
	# The queue draws after pixelation. Hide it while the modal covers the arena.
	if gameOverScreen != null:
		$EnemyQueueVisibilityManager.visible = not gameOverScreen.visible
