extends Node3D 

@export var grid_radius: int = 4
var hex_size: float = 1.0
var hex_height: float 

var occupied_cells: Dictionary = {}
var valid_cells: Dictionary = {}

var cell_meshes: Dictionary[Vector2i,MeshInstance3D] = {}
var highlighted_cells: Dictionary = {}

var hex_mesh := preload("res://Meshes/cell.tres")

# Materials
var material_base := preload("res://Materials/hex_base.tres")
var material_attack := preload("res://Materials/hex_glow_attack.tres")
var material_move := preload("res://Materials/hex_glow_move.tres")
var material_select := preload("res://Materials/hex_glow_select.tres")

const DIRECTIONS = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, -1)
	
]

func _ready():
	hex_height = hex_mesh.height
	generate_grid()

func generate_grid():
	for q in range(-grid_radius, grid_radius + 1):
		for r in range(-grid_radius, grid_radius + 1):
			
			if max(abs(q), abs(r), abs(q + r)) > grid_radius:
				continue
			
			var coord := Vector2i(q, r)
			valid_cells[coord] = true
			create_hex_cell(coord)

func hex_to_world(coord: Vector2i) -> Vector3:
	var q = coord.x
	var r = coord.y
	
	var x = hex_size * sqrt(3.0) * (q + r * 0.5)
	var z = hex_size * 1.5 * r
	
	return Vector3(x, 0, z)

func world_to_hex(positionCheck: Vector3) -> Vector2i:
	var q = (sqrt(3.0) / 3.0 * positionCheck.x
		- 1.0 / 3.0 * positionCheck.z) / hex_size
	var r = (2.0 / 3.0 * positionCheck.z) / hex_size
	
	return axial_round(q, r)

func axial_round(q: float, r: float) -> Vector2i:
	var x = q
	var z = r
	var y = -x - z
	
	var rx = round(x)
	var ry = round(y)
	var rz = round(z)
	
	var x_diff = abs(rx - x)
	var y_diff = abs(ry - y)
	var z_diff = abs(rz - z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))

func create_hex_cell(coord: Vector2i):
	var mesh_instance := MeshInstance3D.new()
	
	mesh_instance.mesh = hex_mesh
	mesh_instance.position = hex_to_world(coord)
	
	add_child(mesh_instance)
	
	cell_meshes[coord] = mesh_instance

func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	
	for direction in DIRECTIONS:
		neighbors.append(coord + direction)
	
	return neighbors
func get_ring(center:Vector2i, radius:int) -> Array[Vector2i]:
	var results:Array[Vector2i]
	# 4 works since the ring starts by moving right
	var hex := center + DIRECTIONS[4] * radius
	for i in range(6):
		for j in range(radius):
			results.append(hex)
			hex = hex + DIRECTIONS[i]
	return results

func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq = a.x - b.x
	var dr = a.y - b.y
	
	return (
		abs(dq)
		+ abs(dr)
		+ abs(dq + dr)
	) / 2


func is_occupied(coord: Vector2i) -> bool:
	return occupied_cells.has(coord)

func set_occupied(coord: Vector2i, value):
	if value:
		occupied_cells[coord] = value
	else:
		occupied_cells.erase(coord)
		

func is_valid_cell(coord: Vector2i) -> bool:
	return valid_cells.has(coord)

func raycast(start:Vector2i,direction:Vector2i,length:int, track_occupied:bool = false) -> Vector2i:
	var cell
	for i in range(1,length+1):
		cell = start + direction*i
		if not is_valid_cell(cell) or (track_occupied and is_occupied(cell)):
			cell = start + direction*(i-1)
			break
	return cell

func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	
	g_score[start] = 0
	f_score[start] = hex_distance(start, goal)
	
	while not open_set.is_empty():
		# Find the cell with the lowest f_score
		var current: Vector2i = open_set[0]
		
		for cell in open_set:
			if f_score.get(cell, INF) < f_score.get(current, INF):
				current = cell
		
		# Destination reached
		if current == goal:
			return reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		for neighbor in get_neighbors(current):
			
			# Must be a valid cell
			if not is_valid_cell(neighbor):
				continue
			
			# Avoid occupied cells, except the starting cell
			if is_occupied(neighbor) and neighbor != start:
				continue
			
			var tentative_g_score: int = g_score[current] + 1
			
			if tentative_g_score < g_score.get(neighbor, INF):
				
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = (
					tentative_g_score
					+ hex_distance(neighbor, goal)
				)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	# No path found
	return []

func reconstruct_path(
	came_from: Dictionary,
	current: Vector2i
) -> Array[Vector2i]:
	
	var path: Array[Vector2i] = [current]
	
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	
	return path

func create_highlight(material:ShaderMaterial, coord:Vector2i):
	if not cell_meshes.has(coord):
		return
	
	var cell: MeshInstance3D = cell_meshes[coord]
	cell.material_override = material
	highlighted_cells[coord] = cell

func clear_highlights():
	for coord in highlighted_cells.keys():
		if cell_meshes.has(coord):
			cell_meshes[coord].material_override = null
	highlighted_cells.clear()

func highlight_cells(material:ShaderMaterial,cells:Array[Vector2i]):
	for cell in cells:
		create_highlight(material, cell)

func highlight_line(material:ShaderMaterial,start_cell:Vector2i, direction:Vector2i, distance:int):
	var path: Array[Vector2i] = []
	var current := start_cell + direction
	
	# Get all cells in line
	while valid_cells.has(current):
		# Stop when the Ability's range is reached
		if path.size() >= distance:
			break
		
		path.append(current)
		current += direction
	
	# Apply highlight to all cells in path
	for cell in path:
		create_highlight(material, cell)
