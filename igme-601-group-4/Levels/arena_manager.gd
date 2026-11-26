extends Node3D

class_name ArenaManager

@onready var enemy_parent = get_node_or_null("Enemies")
@onready var obstacle_parent = get_node_or_null("Obstacles")
@onready var game_over_screen: GameOver = get_node_or_null("GlobalUIRoot/GameOver")

@export_group("Arena Configuration")
@export_file("*.json") var levels_file: String = "res://Levels/Levels_Data.json"
@export var current_level: StringName
@export var current_stage: int

var current_level_data: Dictionary = {}
@export var walls: Array[WallData] = []

var enemy_scene = preload("res://Characters/Enemy.tscn")
var wall_scene = preload("res://Arena Features/Wall.tscn")
var wall_breakable_scene = preload("res://Arena Features/breakable_wall.tscn")
var enemies:Array[Enemy]
var total_enemies:int = 0

var level_select:PackedScene = load("res://UI/Menus/level_select.tscn")
@onready var scene_transition:SceneTransition = get_node_or_null("SceneTransition")

@export var player_start:Vector2i = Vector2i.MIN

signal last_scene_done
var last_scene_unloaded:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not game_over_screen:
		push_warning("No game over screen found!")
	if not scene_transition:
		push_warning("No scene transition found!")
	
	HexGrid.reset()
	
	await last_scene_done
	
	if player_start != Vector2i.MIN:
		Global.player.movement.spawn_position = player_start
		Global.player.movement.set_pos(player_start)
	
	if game_over_screen:
		game_over_screen.restart_game.connect(func():
			if scene_transition and scene_transition.original_stage:
				var new_scene:ArenaManager = scene_transition.original_stage.instantiate()
				new_scene.current_level = current_level
				Global.switch_scenes(new_scene)
			else:
				get_tree().reload_current_scene())
		game_over_screen.level_select.connect(func():
			var new_scene:LevelSelect = level_select.instantiate()
			## TODO: Change this to unlock here. If player restarts level, this doesn't trigger
			new_scene.unlock_level(current_level)
			Global.switch_scenes(new_scene)
		)
	if current_stage > 0:
		load_level_data()
		if not current_level_data.is_empty():
			spawn_level_contents()
	else:
		# Tutorials and the original Arena do not use numbered JSON layouts.
		if enemy_parent and int(current_level) > 1:
			spawn_enemy(Vector2i(1,1))
			spawn_enemy(Vector2i(3,-1))
			spawn_enemy(Vector2i(-2,-2))
			spawn_enemy(Vector2i(-4,3))
		if walls:
			spawn_walls()

	Global.player.health.died.connect(func(): game_over(false))
	

func _process(_delta):
	if not last_scene_unloaded and get_tree().current_scene == self:
		last_scene_unloaded = true
		last_scene_done.emit()

func spawn_enemy(pos:Vector2i, type = enemy_scene):
	total_enemies += 1
	var new_enemy:Enemy = type.instantiate()
	enemy_parent.add_child(new_enemy)
	new_enemy.movement.set_pos(pos)
	new_enemy.death_animation_finished.connect(enemy_died)
	enemies.push_back(new_enemy)
	
func spawn_walls() -> void:
	if not obstacle_parent:
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
	obstacle_parent.add_child(new_obstacle)
	new_obstacle.movement.set_pos(pos)

func enemy_died():
	total_enemies -= 1
	if total_enemies == 0 and game_over_screen != null and not game_over_screen.visible:
		game_over(true)

func game_over(won:bool):
	
	if game_over_screen != null:
		game_over_screen.visible = true
		game_over_screen.win_screen.visible = won
		game_over_screen.lose_screen.visible = not won

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
		if str(level.get("level_number", "")) == str(current_level):
			current_level_data = level
			print("Loaded Level: ", level.get("level_name", "Unnamed"))
			return

	push_error("Level %d was not found!" % current_level)
	
func spawn_level_contents() -> void:
	# Spawn enemies
	if enemy_parent:
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
	if obstacle_parent:
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
	if game_over_screen != null:
		$EnemyQueueVisibilityManager.visible = not game_over_screen.visible
