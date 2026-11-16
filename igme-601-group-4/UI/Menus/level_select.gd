extends Node3D

class_name LevelSelect

const COAST_DECAY := 9.0
const EDGE_RETURN_RATE := 26.0
const MAX_EDGE_OVERSHOOT := 0.75
const REST_SPEED := 0.03
const REST_DISTANCE := 0.002

## Distance covered by a single wheel notch away from the edges.
@export_range(0.5, 10.0, 0.1, "or_greater") var wheel_pan_step: float = 2.5

@onready var _levels: Node3D = $Levels
@onready var _camera: Camera3D = $Camera3D

var _left_edge: float = 0.0
var _right_edge: float = 0.0
var _pan_speed: float = 0.0
var _steering_inward: bool = false


func _ready() -> void:
	set_process(false)
	var camera_right := _camera.global_basis.x.normalized()
	if _update_pan_bounds(camera_right):
		var current_x := _camera.get_camera_transform().origin.dot(camera_right)
		var start_x := clampf(current_x, _left_edge, _right_edge)
		_camera.global_position += camera_right * (start_x - current_x)


func _update_pan_bounds(camera_right: Vector3) -> bool:
	# At either edge, that level's center lines up with the center of the view.
	var leftmost := INF
	var rightmost := -INF
	for child in _levels.get_children():
		if child is LevelNode:
			var horizontal_position: float = child.global_position.dot(camera_right)
			leftmost = minf(leftmost, horizontal_position)
			rightmost = maxf(rightmost, horizontal_position)
	if leftmost == INF:
		return false
	_left_edge = leftmost
	_right_edge = rightmost
	return true


func _process(delta: float) -> void:
	var camera_right := _camera.global_basis.x.normalized()
	var current_x := _camera.get_camera_transform().origin.dot(camera_right)
	var edge := clampf(current_x, _left_edge, _right_edge)
	var next_x: float
	if current_x == edge or _steering_inward:
		next_x = _coast(current_x, delta)
	else:
		next_x = _spring_back(current_x, edge, delta)

	# Bound repeated wheel input while the camera is already past an edge.
	var limited_x := clampf(next_x, _left_edge - MAX_EDGE_OVERSHOOT, _right_edge + MAX_EDGE_OVERSHOOT)
	if limited_x != next_x:
		_pan_speed = 0.0
		next_x = limited_x

	var rest_x := clampf(next_x, _left_edge, _right_edge)
	if next_x == rest_x:
		_steering_inward = false
	if absf(_pan_speed) < REST_SPEED:
		_steering_inward = false
		if absf(next_x - rest_x) < REST_DISTANCE:
			next_x = rest_x
			_pan_speed = 0.0
			set_process(false)
	_camera.global_position += camera_right * (next_x - current_x)


func _coast(current_x: float, delta: float) -> float:
	var decay := exp(-COAST_DECAY * delta)
	var destination := current_x + _pan_speed * (1.0 - decay) / COAST_DECAY
	var edge := _left_edge if _pan_speed < 0.0 else _right_edge
	if (destination - edge) * _pan_speed <= 0.0:
		_pan_speed *= decay
		return destination

	# Split the frame at impact so the bounce has the same entry speed at any frame rate.
	var impact_speed := _pan_speed - COAST_DECAY * (edge - current_x)
	var time_to_edge := log(_pan_speed / impact_speed) / COAST_DECAY
	_pan_speed = impact_speed
	_steering_inward = false
	return _spring_back(edge, edge, maxf(0.0, delta - time_to_edge))


func _spring_back(current_x: float, edge: float, delta: float) -> float:
	# A critically damped spring absorbs the overshoot and settles without oscillating.
	var offset := current_x - edge
	var slope := _pan_speed + EDGE_RETURN_RATE * offset
	var decay := exp(-EDGE_RETURN_RATE * delta)
	_pan_speed = (_pan_speed - EDGE_RETURN_RATE * slope * delta) * decay
	return edge + (offset + slope * delta) * decay


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	var direction: float
	match wheel.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			direction = -1.0
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			direction = 1.0
		_:
			return
	var camera_right := _camera.global_basis.x.normalized()
	if not _update_pan_bounds(camera_right):
		return

	# A wheel turn back toward the levels takes over from the spring.
	var current_x := _camera.get_camera_transform().origin.dot(camera_right)
	var offset := current_x - clampf(current_x, _left_edge, _right_edge)
	_steering_inward = offset * direction < 0.0
	if _pan_speed * direction < 0.0:
		_pan_speed = 0.0
	var speed_per_notch := wheel_pan_step * COAST_DECAY
	var speed_limit := 2.0 * speed_per_notch
	_pan_speed = clampf(_pan_speed + direction * speed_per_notch * wheel.factor, -speed_limit, speed_limit)
	set_process(true)
	get_viewport().set_input_as_handled()

func get_level_from_id(id:StringName) -> LevelNode:
	for child in _levels.get_children():
		if child is LevelNode:
			var level = child as LevelNode
			if level.level_id == id:
				return level
	return null

func unlock_level(origin_level_id:StringName) -> void:
	if not is_node_ready():
		await ready
	var origin_level = get_level_from_id(origin_level_id)
	if origin_level:
		for level in origin_level.next_levels:
			level.active = true
	else:
		push_error("id not found: " + origin_level_id)
