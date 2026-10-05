extends Node3D
class_name HexGrid
#Test
@export var grid_radius: int = 4
@export var hex_size: float = 1.0
@export var cell_height: float 

var occupied_cells: Dictionary = {}
var valid_cells: Dictionary = {}

var cell_meshes: Dictionary = {}
var highlighted_cells: Dictionary = {}
var highlight_material := ShaderMaterial.new()
var dash_path_material := ShaderMaterial.new()
var hover_material := ShaderMaterial.new()


const DIRECTIONS = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1)
]


const HEX_GLOW_SHADER := """
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.3, 1.0);

uniform float glow_strength = 4.0;
uniform float glow_speed = 3.0;
uniform float edge_thickness = 0.2;

varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// Normalize so the hex circumradius is 1.0
	vec2 p = local_position.xz / 0.95;

	vec2 normals[6];
	normals[0] = vec2(1.0, 0.0);
	normals[1] = vec2(0.5, 0.8660254);
	normals[2] = vec2(-0.5, 0.8660254);
	normals[3] = vec2(-1.0, 0.0);
	normals[4] = vec2(-0.5, -0.8660254);
	normals[5] = vec2(0.5, -0.8660254);

	// Distance to the nearest edge. Edges sit at the apothem (0.866), not 1.0
	float edge_distance = 1.0;
	for (int i = 0; i < 6; i++) {
		edge_distance = min(edge_distance, 0.8660254 - dot(p, normals[i]));
	}

	// Top face only, detected by normal
	float top_mask = step(0.9, local_normal.y);

	float edge_mask = 1.0 - smoothstep(0.0, edge_thickness, edge_distance);

	float pulse = 0.5 + 0.5 * sin(TIME * glow_speed);
	float glow = edge_mask * top_mask * (0.5 + pulse);

	ALBEDO = base_color.rgb;
	EMISSION = glow_color.rgb * glow * glow_strength;
	ROUGHNESS = 0.5;
}
"""

func _ready():
	# Create shader
	var shader := Shader.new()
	shader.code = HEX_GLOW_SHADER

	# Movable-cell highlight
	highlight_material.shader = shader
	highlight_material.set_shader_parameter(
	"base_color",
	Color(0.20, 0.20, 0.20)
)

	highlight_material.set_shader_parameter(
		"glow_color",
		Color(1.0, 1.0, 0.3)
	)

	# Dash path
	var dash_shader := Shader.new()
	dash_shader.code = HEX_GLOW_SHADER

	dash_path_material.shader = dash_shader
	dash_path_material.set_shader_parameter(
	"base_color",
	Color(0.20, 0.20, 0.20)
)

	dash_path_material.set_shader_parameter(
		"glow_color",
		Color(0.3, 0.7, 1.0)
	)

	# Dash destination
	var destination_shader := Shader.new()
	destination_shader.code = HEX_GLOW_SHADER

	hover_material.shader = destination_shader
	hover_material.set_shader_parameter(
		"glow_color",
		Color(1.0, 0.1, 0.1)
	)
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
	var mesh := CylinderMesh.new()

	mesh.top_radius = hex_size * 0.95
	mesh.bottom_radius = hex_size * 0.95
	mesh.height = cell_height
	mesh.radial_segments = 6

	mesh_instance.mesh = mesh
	mesh_instance.position = hex_to_world(coord)

	add_child(mesh_instance)

	cell_meshes[coord] = mesh_instance


func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []

	for direction in DIRECTIONS:
		neighbors.append(coord + direction)

	return neighbors


func is_occupied(coord: Vector2i) -> bool:
	return occupied_cells.has(coord)


func set_occupied(coord: Vector2i, value: bool):
	if value:
		occupied_cells[coord] = true
	else:
		occupied_cells.erase(coord)
		

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
			if not valid_cells.has(neighbor):
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

func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq = a.x - b.x
	var dr = a.y - b.y

	return (
		abs(dq)
		+ abs(dr)
		+ abs(dq + dr)
	) / 2


func reconstruct_path(
	came_from: Dictionary,
	current: Vector2i
) -> Array[Vector2i]:

	var path: Array[Vector2i] = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	return path
	
func highlight_movable_cells(center_cell: Vector2i):
	clear_highlights()

	for neighbor in get_neighbors(center_cell):

		if not valid_cells.has(neighbor):
			continue

		if is_occupied(neighbor):
			continue

		create_highlight(
			neighbor,
			highlight_material
		)
		
		
func create_highlight(
	coord: Vector2i,
	material: Material
):
	if not cell_meshes.has(coord):
		return

	var cell: MeshInstance3D = cell_meshes[coord]

	cell.material_override = material

	highlighted_cells[coord] = cell
	
func highlight_dash_path(
	start_cell: Vector2i,
	direction: Vector2i,
	destination_cell: Variant = null,
	max_distance: int = -1
) -> Array[Vector2i]:

	clear_highlights()

	var path: Array[Vector2i] = []
	var current := start_cell + direction

	while valid_cells.has(current):

		# Stop when the Ability's range is reached
		if max_distance != -1 and path.size() >= max_distance:
			break

		# Stop if another object is blocking the dash
		if is_occupied(current):
			break

		path.append(current)

		# Stop at selected destination
		if destination_cell != null and current == destination_cell:
			break

		current += direction

	if path.is_empty():
		return []

	# Light blue path
	for cell in path:
		create_highlight(cell, dash_path_material)

	# Red destination
	if destination_cell != null and destination_cell in path:
		create_highlight(
			destination_cell,
			hover_material
		)

	return path
	
	
func clear_highlights():
	for coord in highlighted_cells.keys():
		if cell_meshes.has(coord):
			cell_meshes[coord].material_override = null

	highlighted_cells.clear()

func highlight_hover(cell: Vector2i):
	if valid_cells.has(cell) and not is_occupied(cell):
		create_highlight(cell, hover_material)
