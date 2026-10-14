extends CharacterBody3D
class_name PlayerController

@onready var camera:Camera3D = get_viewport().get_camera_3d()
@export var movement:CharacterMovement

@export_category("Abilities")
@export var abilities: Array[Ability] = []
var selected_ability:Ability = null

enum PlayerMode {
	NONE,
	TARGETING,
	ACTING
}
var current_mode := PlayerMode.NONE

var cursor_position:Vector2i

func _ready():
	var spawn_position := HexGrid.hex_to_world(movement.current_cell)
	spawn_position.y = HexGrid.hex_height / 2.0 + 1

	global_position = HexGrid.to_global(spawn_position)

	HexGrid.set_occupied(movement.current_cell, true)

func _process(_delta):
	match current_mode:
		PlayerMode.NONE:
			
			pass
		PlayerMode.TARGETING:
			
			pass
		PlayerMode.ACTING:
			## Carry out during Action Phase, after queue is made
			pass

func _unhandled_input(event):
# All the key press below is for testing purposes
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if current_mode == PlayerMode.NONE:
				match event.keycode:
					KEY_M: 
						add_ability(get_ability("Move"))
					KEY_D:
						add_ability(get_ability("Dash"))
					KEY_S:
						add_ability(get_ability("Slash"))
				preview_target(selected_ability,cursor_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_mode == PlayerMode.TARGETING:
			current_mode = PlayerMode.NONE
			HexGrid.clear_highlights()
			var target_data = get_target(selected_ability,cursor_position)
			
			## For now, just execute the ability with the information aleady gathered
			execute_ability(selected_ability,target_data)
		else:
			print("Occupied: " + str(HexGrid.occupied_cells))
	elif event is InputEventMouseMotion:
		cursor_position = event.position
		if current_mode == PlayerMode.TARGETING:
			preview_target(selected_ability,cursor_position)

# ======Ability Template====== 
func get_ability(ability_name: String) -> Ability:
	for ability in abilities:
		if ability.ability_name == ability_name:
			return ability
	return null

# Adds ability to the queue. Some abilities require input before being added.
func add_ability(ability:Ability) -> void:
	if ability == null:
		return
	
	print("Using ability: ", ability.ability_name)
	
	match ability.targeting_type:
		Global.TargetingType.NONE:
			# Add ability to queue
			## Need to add ability to queue immediately (as of right now, there are no abilities with NONE)
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

# Updates the grid display
func preview_target(ability:Ability, mouse_position:Vector2):
	HexGrid.clear_highlights()
	var target_data = get_target(ability,mouse_position)
	var highlightMat:ShaderMaterial
	
	# Select material
	match ability.type:
		Global.AbilityType.MOVEMENT:
			highlightMat = HexGrid.material_move
		Global.AbilityType.ATTACK:
			highlightMat = HexGrid.material_attack
	
	# Highlight cells
	match ability.targeting_type:
		Global.TargetingType.NONE:
			pass
		Global.TargetingType.DIRECTION:
			if !target_data or target_data == Vector2i.ZERO:
				return
			# Display all directions as one color, then the target as another
			for direction:Vector2i in HexGrid.DIRECTIONS:
				HexGrid.highlight_line(highlightMat,movement.current_cell,direction,ability.range)
			HexGrid.highlight_line(HexGrid.material_select,movement.current_cell,target_data,ability.range)
		Global.TargetingType.SHAPE:
			pass
		Global.TargetingType.SINGLE_TILE:
			var cells:Array[Vector2i]
			for i in range(ability.range):
				cells.append_array(HexGrid.get_ring(movement.current_cell,i+1))
			if cells:
				HexGrid.highlight_cells(highlightMat,cells)
			if(target_data):
				HexGrid.create_highlight(HexGrid.material_select,target_data)

# Returns appropriate target data based on target type
	# DIRECTION: returns a Vector2i for direction
	# SINGLE_TILE: returns a Vector2i for a single cell
# Returns false if selected target is unacceptable
func get_target(ability:Ability, mouse_position:Vector2):
	var clicked_cell = get_clicked_hex(mouse_position)
	
	# Validate cell
	if clicked_cell == null or not HexGrid.is_valid_cell(clicked_cell):
		return
	
	match ability.targeting_type:
		Global.TargetingType.NONE:
			pass
		Global.TargetingType.DIRECTION:
			var difference: Vector2i = clicked_cell - movement.current_cell
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
			if HexGrid.hex_distance(clicked_cell,movement.current_cell) > ability.range:
				return false
			return clicked_cell

func execute_ability(ability:Ability, target_data):
	print("Executing: " + str(ability.ability_name))
	match ability.type:
		Global.AbilityType.MOVEMENT:
			if(ability.targeting_type == Global.TargetingType.DIRECTION):
				target_data = HexGrid.raycast(movement.current_cell,target_data,ability.range)
			print("Moving to: " + str(target_data))
			movement.pathfind(target_data)
		Global.AbilityType.ATTACK:
			pass

func get_clicked_hex(mouse_position: Vector2):
	# Create a ray from the camera through the mouse position
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	
	# Avoid division by zero
	if abs(ray_direction.y) < 0.001:
		return null
		
	# Find where the ray intersects the hex grid plane
	var grid_y = HexGrid.global_position.y
	var distance = (grid_y - ray_origin.y) / ray_direction.y
	if distance < 0:
		return null
	var hit_position = ray_origin + ray_direction * distance
	
	# Convert global position to HexGrid local space
	var local_position = HexGrid.to_local(hit_position)
	
	# Convert world position to hex coordinate
	return HexGrid.world_to_hex(local_position)
