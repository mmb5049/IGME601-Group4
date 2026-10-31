extends Node3D

## Shared head anchor for player and enemy action numbers. Projecting into a
## CanvasLayer keeps the text upright and independent of camera distance.
@onready var _label: Label = $CanvasLayer/Number
var _actor: Node3D


func _ready() -> void:
	_actor = get_parent() as Node3D
	_actor.connect("action_number_changed", _refresh_number)
	if _actor is Enemy:
		_actor.died.connect(_hide_number)
	elif _actor is PlayerController:
		_actor.player_died.connect(_hide_number)
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
	var screen_position: Vector2 = camera.unproject_position(global_position)
	_label.visible = (
		not _label.text.is_empty()
		and not camera.is_position_behind(global_position)
		and get_viewport().get_visible_rect().has_point(screen_position)
	)
	_label.position = screen_position - _label.size * 0.5


func _hide_number() -> void:
	_label.hide()
	set_process(false)
