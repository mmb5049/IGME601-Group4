extends CharacterBody3D
class_name PlayerController

var move_speed: float = 10.0
var dash_speed: float = 25.0
var current_speed: float

@onready var hex_grid: HexGrid = get_parent().get_node("HexGrid")
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var current_cell: Vector2i = Vector2i.ZERO

var path: Array[Vector2i] = []

var target_cell: Vector2i

var is_moving := false
var is_dashing := false


enum PlayerMode {
	NONE,
	MOVE,
	DASH
}
var current_mode := PlayerMode.NONE

var dash_path: Array[Vector2i] = []

func _ready():
	global_position = hex_grid.to_global(
		hex_grid.hex_to_world(current_cell)
	)

	hex_grid.set_occupied(current_cell, true)

func _physics_process(delta):
	if current_mode == PlayerMode.DASH and not is_moving:
		update_dash_preview()
		
	if is_moving or is_dashing:
		move_to_target(delta)



func _unhandled_input(event):

	if event is InputEventKey:
		if event.pressed and not event.echo:

			if event.keycode == KEY_M:
				enter_move_mode()
				return

			if event.keycode == KEY_D:
				enter_dash_mode()
				return

	if event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if not event.pressed:
			return

		if is_moving:
			return

		if current_mode == PlayerMode.MOVE:
			handle_move_click(event.position)

		elif current_mode == PlayerMode.DASH:
			handle_dash_click()


func get_clicked_hex(mouse_position: Vector2):
	# Create a ray from the camera through the mouse position
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)

	# Avoid division by zero
	if abs(ray_direction.y) < 0.001:
		return null

	# Find where the ray intersects the hex grid plane
	var grid_y := hex_grid.global_position.y

	var distance := (grid_y - ray_origin.y) / ray_direction.y

	if distance < 0:
		return null

	var hit_position := ray_origin + ray_direction * distance

	# Convert global position to HexGrid local space
	var local_position := hex_grid.to_local(hit_position)

	# Convert world position to hex coordinate
	return hex_grid.world_to_hex(local_position)



func move_to_target(delta):

	var target_position := hex_grid.to_global(
		hex_grid.hex_to_world(target_cell)
	)

	current_speed = dash_speed if is_dashing else move_speed

	global_position = global_position.move_toward(
		target_position,
		current_speed * delta
	)

	if global_position.distance_to(target_position) < 0.01:

		global_position = target_position

		current_cell = target_cell

		if not path.is_empty():

			target_cell = path.pop_front()

			hex_grid.set_occupied(current_cell, false)
			hex_grid.set_occupied(target_cell, true)

		else:

			is_moving = false
			is_dashing = false

			# Return to no mode after the action
			current_mode = PlayerMode.NONE
			hex_grid.clear_highlights()

func enter_move_mode():

	if is_moving:
		return

	current_mode = PlayerMode.MOVE

	dash_path.clear()

	hex_grid.highlight_movable_cells(current_cell)
	
func enter_dash_mode():
	if is_moving:
		return

	current_mode = PlayerMode.DASH

	dash_path.clear()

	update_dash_preview()
	
func handle_move_click(mouse_position: Vector2):

	var clicked_cell: Variant = get_clicked_hex(mouse_position)

	if clicked_cell == null:
		return

	var next_cell: Vector2i = clicked_cell

	# Only allow adjacent cells
	if next_cell not in hex_grid.get_neighbors(current_cell):
		return

	# Must be valid
	if not is_valid_cell(next_cell):
		return

	# Cannot move onto occupied cell
	if hex_grid.is_occupied(next_cell):
		return

	var new_path := hex_grid.find_path(
		current_cell,
		next_cell
	)

	if new_path.is_empty():
		return

	new_path.pop_front()

	if new_path.is_empty():
		return

	path = new_path

	target_cell = path.pop_front()

	is_moving = true

	hex_grid.clear_highlights()

	hex_grid.set_occupied(current_cell, false)
	hex_grid.set_occupied(target_cell, true)
	
func get_dash_direction(mouse_position: Vector2) -> Vector2i:

	var clicked_cell: Variant = get_clicked_hex(mouse_position)

	if clicked_cell == null:
		return Vector2i.ZERO

	var difference: Vector2i = clicked_cell - current_cell

	if difference == Vector2i.ZERO:
		return Vector2i.ZERO

	var best_direction := Vector2i.ZERO
	var best_score := -INF

	for direction in hex_grid.DIRECTIONS:

		var distance := hex_grid.hex_distance(
			current_cell,
			clicked_cell
		)

		if distance == 0:
			continue

		# Normalize both vectors conceptually using dot product
		var direction_vector := Vector2(
			direction.x,
			direction.y
		)

		var difference_vector := Vector2(
			difference.x,
			difference.y
		).normalized()

		var score := direction_vector.normalized().dot(
			difference_vector
		)

		if score > best_score:
			best_score = score
			best_direction = direction

	return best_direction	
	
func handle_dash_click():

	if dash_path.is_empty():
		return

	var destination := dash_path[-1]

	if not is_valid_cell(destination):
		return

	if hex_grid.is_occupied(destination):
		return

	path = dash_path.duplicate()

	hex_grid.clear_highlights()

	target_cell = path.pop_front()

	is_dashing = true
	is_moving = true

	hex_grid.set_occupied(current_cell, false)
	hex_grid.set_occupied(target_cell, true)
	
func update_dash_preview():

	if current_mode != PlayerMode.DASH:
		return

	var mouse_position := get_viewport().get_mouse_position()

	var direction := get_dash_direction(mouse_position)

	if direction == Vector2i.ZERO:
		hex_grid.clear_highlights()
		dash_path.clear()
		return

	var mouse_cell: Variant = get_clicked_hex(mouse_position)

	if mouse_cell == null:
		return

	# First find the full possible dash path
	var full_path := hex_grid.highlight_dash_path(
		current_cell,
		direction
	)

	if full_path.is_empty():
		dash_path.clear()
		return

	# Only allow the mouse to select a cell that is
	# actually on the dash path
	var destination_index := full_path.find(mouse_cell)

	if destination_index == -1:
		# Mouse isn't over a valid dash cell.
		dash_path = full_path
		return

	# Only keep the path up to the mouse position
	dash_path = full_path.slice(0, destination_index + 1)

	# Redraw so the mouse cell becomes yellow
	hex_grid.highlight_dash_path(
		current_cell,
		direction,
		mouse_cell
	)

func is_valid_cell(coord: Vector2i) -> bool:
	return hex_grid.valid_cells.has(coord)
	
