extends CharacterBody3D
class_name PlayerController

var move_speed: float = 10.0
var dash_speed: float = 25.0
var current_speed: float

@onready var camera: Camera3D = get_viewport().get_camera_3d()

var current_cell: Vector2i = Vector2i.ZERO

var path: Array[Vector2i] = []

var target_cell: Vector2i

var is_moving := false
var is_dashing := false

@export_category("Abilities")
@export var abilities: Array[Ability] = []
var active_ability: Ability = null

enum PlayerMode {
	NONE,
	TARGETING,
	ACTING
}
var current_mode := PlayerMode.NONE
var selected_ability:Ability = null

var dash_path: Array[Vector2i] = []

func _ready():
	var spawn_position := HexGrid.hex_to_world(current_cell)
	spawn_position.y = HexGrid.instance.cell_height / 2.0 + 1

	global_position = HexGrid.instance.to_global(spawn_position)

	HexGrid.instance.set_occupied(current_cell, true)
func _process(delta):
	pass
func _unhandled_input(event):
# All the key press below is for testing purposes
	if event is InputEventKey:
		if event.pressed and not event.echo:

			if event.keycode == KEY_M:
				add_ability(get_ability("Move"))
				return

			if event.keycode == KEY_D:
				add_ability(get_ability("Dash"))
				return

			if event.keycode == KEY_S:
				add_ability(get_ability("Slash"))
				return

	if event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if not event.pressed:
			return

		if is_moving:
			return

# ======Ability Template====== 
func get_ability(ability_name: String) -> Ability:
	for ability in abilities:
		if ability.ability_name == ability_name:
			return ability
	return null

func add_ability(ability: Ability) -> void:
	if ability == null:
		return

	## Remove after queue is functioning
	if is_moving:
		return

	print("Using ability: ", ability.ability_name)

	match ability.targeting_type:
		Global.TargetingType.NONE:
			# Add ability to queue
			pass
		Global.TargetingType.DIRECTION:
			# Get direction
			current_mode = PlayerMode.TARGETING
			selected_ability = ability
		Global.TargetingType.SHAPE:
			# Get shape location
			current_mode = PlayerMode.TARGETING
			selected_ability = ability
		Global.TargetingType.SINGLE_TILE:
			# Get tile location
			current_mode = PlayerMode.TARGETING
			selected_ability = ability
	#match ability.type:
		#Ability.AbilityType.MOVEMENT:
			#use_movement_ability(ability)
		#Ability.AbilityType.ATTACK:
			#use_attack_ability(ability)
		#Ability.AbilityType.TRAP:
			#use_trap_ability(ability)
		#Ability.AbilityType.STATUS:
			#use_status_ability(ability)
		#Ability.AbilityType.DEFENSE:
			#use_defense_ability(ability)	

# Updates the grid display
func preview_target(ability:Ability, mouse_position:Vector2):
	HexGrid.instance.clear_highlights()
	var target_data = get_target(ability,mouse_position)
	match ability.targeting_type:
		Global.TargetingType.NONE:
			pass
		Global.TargetingType.DIRECTION:
			var direction = target_data;
			
			if direction == Vector2i.ZERO:
				return
			
			HexGrid.instance.highlight_line(HexGrid.instance.material_blue,current_cell,direction,ability.range)
		Global.TargetingType.SHAPE:
			pass
		Global.TargetingType.SINGLE_TILE:
			if(target_data):
				HexGrid.instance.create_highlight(HexGrid.instance.material_blue,target_data)
			pass
	pass

# Returns appropriate target data based on target type
	# DIRECTION: returns a Vector2i for direction
	# SINGLE_TILE: returns a Vector2i for a single cell
# Returns false if selected target is unacceptable
func get_target(ability:Ability, mouse_position:Vector2):
	var clicked_cell = get_clicked_hex(mouse_position)
	
	# Validate cell
	if clicked_cell == null or not HexScript.is_valid_cell(clicked_cell):
		return
	
	match ability.targeting_type:
		Global.TargetingType.NONE:
			pass
		Global.TargetingType.DIRECTION:
			var difference: Vector2i = clicked_cell - current_cell
			if difference == Vector2i.ZERO:
				return false
			
			# Test each direction to find the best
			var best_direction := Vector2i.ZERO
			var best_score := -INF
			for direction:Vector2i in HexGrid.DIRECTIONS:
				# Normalize both vectors conceptually using dot product
				var score = direction.x * difference.x + direction.y * difference.y
				if score > best_score:
					best_score = score
					best_direction = direction
			return best_direction
		Global.TargetingType.SHAPE:
			pass
		Global.TargetingType.SINGLE_TILE:
			# Limit to range
			if HexScript.hex_distance(clicked_cell,current_cell) > ability.range:
				return false
			return clicked_cell
	pass

func get_clicked_hex(mouse_position: Vector2):
	# Create a ray from the camera through the mouse position
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	
	# Avoid division by zero
	if abs(ray_direction.y) < 0.001:
		return null
		
	# Find where the ray intersects the hex grid plane
	var grid_y := HexGrid.instance.global_position.y
	var distance := (grid_y - ray_origin.y) / ray_direction.y
	if distance < 0:
		return null
	var hit_position := ray_origin + ray_direction * distance
	
	# Convert global position to HexGrid local space
	var local_position := HexGrid.instance.to_local(hit_position)
	
	# Convert world position to hex coordinate
	return HexGrid.instance.world_to_hex(local_position)
