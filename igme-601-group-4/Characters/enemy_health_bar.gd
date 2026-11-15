extends Node3D

signal damage_animation_finished

const DAMAGE_DURATION: float = 0.2
const FILL_LIFT: float = 0.004
const DAMAGE_SHADER := preload("res://Materials/Shaders/enemy_health_loss.gdshader")
const DAMAGE_THROUGH_WALL_SHADER := preload("res://Materials/Shaders/enemy_health_loss_through_wall.gdshader")
# Draw after the model outline, then layer the backing, cells and damage in order.
const BACKING_PRIORITY: int = 23
const CELL_PRIORITY: int = 24
const DAMAGE_PRIORITY: int = 25

@export_range(0.2, 3.0, 0.01, "suffix:m") var arc_radius: float = 0.92
@export_range(5.0, 170.0, 1.0, "degrees") var arc_angle: float = 84.0
@export_range(0.02, 0.4, 0.005, "suffix:m") var fill_width: float = 0.12
@export_range(0.0, 0.1, 0.001, "suffix:m") var outline_width: float = 0.026
@export_range(0.0, 0.2, 0.001, "suffix:m") var cell_gap: float = 0.034
@export_range(0.0, 0.3, 0.005, "suffix:m") var damage_spread: float = 0.09
@export var fill_color: Color = Color(1.0, 0.10, 0.12)
@export var damage_color: Color = Color(1.0, 0.85, 0.15)

var _backing: MeshInstance3D
var _cells: Array[MeshInstance3D] = []
var _filled: int = 0
var _damage_materials: Array[ShaderMaterial] = []
var _show_through_walls: bool = false

@onready var _normal_position := position
@onready var _normal_scale := scale


func set_hover_scale(factor: float, model_origin: Vector3) -> void:
	# Scale about the model's ground projection at the bar's original height.
	model_origin.y = _normal_position.y
	position = model_origin.lerp(_normal_position, factor)
	scale = _normal_scale * Vector3(factor, 1.0, factor)


func set_show_through_walls(enabled: bool) -> void:
	_show_through_walls = enabled
	if _backing != null:
		_set_flat_depth(_backing.material_override, BACKING_PRIORITY)
		_set_flat_depth(_cells[0].material_override, CELL_PRIORITY)
	for material in _damage_materials:
		var progress: float = material.get_shader_parameter("progress")
		_configure_damage_material(material, progress)


func bind_health(health: Health) -> void:
	health.changed.connect(_update_health)
	_update_health(health.current, health.max)


func is_animating_damage() -> bool:
	return not _damage_materials.is_empty()


func _update_health(current_health: int, max_health: int) -> void:
	var capacity := maxi(0, max_health)
	var filled := clampi(current_health, 0, capacity)
	if _cells.size() != capacity:
		_rebuild(capacity)
		_filled = filled
		for index in range(_cells.size()):
			_cells[index].visible = index < filled
		return

	if filled < _filled:
		_play_damage(filled, _filled)
	elif filled > _filled:
		for index in range(_filled, filled):
			_cells[index].show()
	_filled = filled


func _rebuild(capacity: int) -> void:
	for cell in _cells:
		cell.hide()
		cell.queue_free()
	_cells.clear()
	if _backing != null:
		_backing.hide()
		_backing.queue_free()
		_backing = null
	if capacity == 0:
		return

	var half_angle := deg_to_rad(arc_angle) * 0.5
	var half_fill := fill_width * 0.5
	# Convert the end border and the cell gaps from world length to radians.
	var end_border := minf(outline_width / arc_radius, half_angle * 0.25)
	var step := (2.0 * (half_angle - end_border)) / capacity
	var gap := minf(cell_gap / arc_radius, step * 0.8)
	_backing = _add_strip(
		_strip_mesh(-half_angle, half_angle, half_fill + outline_width),
		_flat_material(Color.BLACK, BACKING_PRIORITY), 0.0
	)
	var red := _flat_material(fill_color, CELL_PRIORITY)
	for index in range(capacity):
		var start := -half_angle + end_border + index * step
		var end := start + step
		if index > 0:
			start += gap * 0.5
		if index < capacity - 1:
			end -= gap * 0.5
		_cells.append(_add_strip(_strip_mesh(start, end, half_fill), red, FILL_LIFT))


func _strip_mesh(start: float, end: float, half_width: float) -> ArrayMesh:
	var strip := SurfaceTool.new()
	strip.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var segments := maxi(1, ceili((end - start) / deg_to_rad(3.0)))
	for index in range(segments + 1):
		var angle := lerpf(start, end, float(index) / segments)
		var radial := Vector3(sin(angle), 0.0, cos(angle))
		var center := radial * arc_radius - Vector3.BACK * arc_radius
		strip.set_uv(Vector2(angle, -1.0))
		strip.add_vertex(center - radial * half_width)
		strip.set_uv(Vector2(angle, 1.0))
		strip.add_vertex(center + radial * half_width)
	return strip.commit()


func _flat_material(color: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	_set_flat_depth(material, priority)
	return material


func _set_flat_depth(material: StandardMaterial3D, priority: int) -> void:
	material.no_depth_test = _show_through_walls
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _show_through_walls else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.render_priority = priority if _show_through_walls else 0


func _add_strip(mesh: Mesh, material: Material, lift: float) -> MeshInstance3D:
	var strip := MeshInstance3D.new()
	strip.mesh = mesh
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position.y = lift
	add_child(strip)
	return strip


func _configure_damage_material(material: ShaderMaterial, progress: float) -> void:
	material.shader = DAMAGE_THROUGH_WALL_SHADER if _show_through_walls else DAMAGE_SHADER
	material.render_priority = DAMAGE_PRIORITY if _show_through_walls else 0
	material.set_shader_parameter("fill_color", fill_color)
	material.set_shader_parameter("damage_color", damage_color)
	material.set_shader_parameter("spread", damage_spread)
	material.set_shader_parameter("progress", progress)


func _play_damage(first: int, end: int) -> void:
	var material := ShaderMaterial.new()
	_configure_damage_material(material, 0.0)
	var fragments: Array[MeshInstance3D] = []
	for index in range(first, end):
		var cell := _cells[index]
		cell.hide()
		var fragment := _add_strip(cell.mesh, material, FILL_LIFT * 2.0)
		fragment.extra_cull_margin = damage_spread
		fragments.append(fragment)

	_damage_materials.append(material)
	var animation := create_tween()
	animation.tween_method(
		func(progress: float): material.set_shader_parameter("progress", progress),
		0.0, 1.0, DAMAGE_DURATION
	)
	animation.finished.connect(_finish_damage.bind(fragments, material))


func _finish_damage(fragments: Array[MeshInstance3D], material: ShaderMaterial) -> void:
	for fragment in fragments:
		fragment.queue_free()
	_damage_materials.erase(material)
	if _damage_materials.is_empty():
		damage_animation_finished.emit()
