extends Node

## One temporary playback session. Grid occupancy, actor transform and
## collisions never move. Cancellation always restores the visual transform.
signal completed(succeeded: bool)

var _visual: Node3D
var _saved_transform: Transform3D
var _home: Vector3
var _tween: Tween
var _finished: bool = false


func play(actor: Node3D, visual: Node3D, route: PackedVector3Array, duration: float) -> bool:
	_visual = visual
	_saved_transform = visual.transform
	_home = route[0]
	actor.tree_exiting.connect(cancel, CONNECT_ONE_SHOT)
	if actor is Character:
		actor.health.died.connect(cancel, CONNECT_ONE_SHOT)
	var total_distance: float = 0.0
	for index in range(1, route.size()):
		total_distance += route[index - 1].distance_to(route[index])
	if total_distance <= 0.001:
		return false
	_tween = create_tween()
	for index in range(1, route.size()):
		var start: Vector3 = route[index - 1]
		var end: Vector3 = route[index]
		var seconds: float = duration * start.distance_to(end) / total_distance
		_tween.tween_method(_move_leg.bind(start, end), 0.0, 1.0, seconds)
	_tween.finished.connect(_finish.bind(true), CONNECT_ONE_SHOT)
	return await completed


func _move_leg(progress: float, start: Vector3, end: Vector3) -> void:
	if not is_instance_valid(_visual):
		cancel()
		return
	_visual.global_position = start.lerp(end, progress)
	var direction := _home - _visual.global_position
	# At the center retain the heading of the final approach, even on a skipped frame.
	if direction.is_zero_approx() and end.is_equal_approx(_home):
		direction = _home - start
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_visual.look_at(_visual.global_position + direction, Vector3.UP, true)


func cancel() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_finish(false)


func _finish(succeeded: bool) -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(_visual):
		if succeeded:
			_visual.position = _saved_transform.origin
		else:
			_visual.transform = _saved_transform
	completed.emit(succeeded)


func _exit_tree() -> void:
	cancel()
