extends Camera3D

## Maximum camera-local offset toward the cursor in world units.
@export var mouse_sway_amount: Vector2 = Vector2(0.16, 0.11)
@export_range(0.1, 30.0, 0.1) var mouse_follow_speed: float = 6.0

## Maximum camera-local offset from the idle shake in world units.
@export var idle_shake_amount: Vector2 = Vector2(0.055, 0.04)
@export_range(0.1, 10.0, 0.1) var idle_shake_speed: float = 1.8

var _base_offset: Vector2
var _mouse_offset := Vector2.ZERO
var _shake_time: float = 0.0
var _shake_noise := FastNoiseLite.new()


func _ready() -> void:
	# Apply the offset before gameplay and UI project points through this camera.
	process_priority = -10
	_base_offset = Vector2(h_offset, v_offset)
	_shake_noise.frequency = 1.0
	_shake_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


func _process(delta: float) -> void:
	var mouse := GlobalUISway.get_normalized_mouse_position(get_viewport())
	# Screen Y points down, while the camera's vertical offset points up.
	var target_offset := Vector2(mouse.x, -mouse.y) * mouse_sway_amount
	_mouse_offset = _mouse_offset.lerp(target_offset, 1.0 - exp(-mouse_follow_speed * delta))

	_shake_time += delta * idle_shake_speed
	# Sample two different paths through the noise so the axes vary independently.
	var shake := Vector2(
		_shake_noise.get_noise_2d(_shake_time, 23.0),
		_shake_noise.get_noise_2d(_shake_time, 71.0)
	) * idle_shake_amount
	var offset := _base_offset + _mouse_offset + shake
	h_offset = offset.x
	v_offset = offset.y
