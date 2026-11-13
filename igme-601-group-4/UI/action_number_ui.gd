extends Node3D

## The CanvasLayer keeps action numbers upright and independent of camera distance.
@onready var _label: Label = $CanvasLayer/Number
var _actor: Node3D


func _ready() -> void:
	_actor = get_parent() as Node3D
	_actor.connect("action_number_changed", _refresh_number)
	# The actor initializes its model and health after its children enter the tree.
	await _actor.ready
	if _actor.health:
		_actor.health.died.connect(_hide_number)
	_refresh_number(int(_actor.get("action_number")))
	_update_position()


func _process(_delta: float) -> void:
	_update_position()


func _refresh_number(number: int) -> void:
	_label.text = str(number) if number > 0 else ""


func _update_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_label.hide()
		return
	var screen_position: Vector2
	if _actor is Enemy:
		screen_position = _actor.get_overhead_screen_position(camera)
	elif not camera.is_position_behind(global_position):
		screen_position = camera.unproject_position(global_position)
	else:
		screen_position = Vector2.INF
	if not screen_position.is_finite():
		_label.hide()
		return
	_label.visible = (
		not _label.text.is_empty()
		and get_viewport().get_visible_rect().has_point(screen_position)
	)
	if _actor is Enemy:
		screen_position = _actor.scale_overhead_position(camera, screen_position)
		_label.pivot_offset = _label.size * 0.5
		_label.scale = Vector2.ONE * _actor.hover_scale
	_label.position = screen_position - _label.size * 0.5


func _hide_number() -> void:
	_label.hide()
	set_process(false)
