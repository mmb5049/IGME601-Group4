extends Node3D

const WORLD_UNITS_PER_FONT_PIXEL := 0.01

@onready var _anchor: Node3D = $Anchor
@onready var _pixelation: ShaderMaterial = $CanvasLayer/Pixelation.material
@onready var _label: Label = $CanvasLayer/Pixelation/Number


func _ready() -> void:
	$AnimationPlayer.animation_finished.connect(func(_animation_name): queue_free())


func set_number(number: int) -> void:
	_label.text = str(number)
	_update_position()


func _process(_delta: float) -> void:
	_update_position()


func _update_position() -> void:
	var camera := get_viewport().get_camera_3d()
	var world_position := _anchor.global_position
	if camera == null or camera.is_position_behind(world_position):
		_label.hide()
		return

	# Draw above the overhead queue while retaining the world-space rise and apparent size.
	var screen_position := camera.unproject_position(world_position)
	var camera_right := camera.global_basis.x.normalized()
	var screen_unit := camera.unproject_position(world_position + camera_right)
	var anchor_scale := _anchor.global_basis.get_scale()
	_label.scale = Vector2(anchor_scale.x, anchor_scale.y) \
			* screen_position.distance_to(screen_unit) * WORLD_UNITS_PER_FONT_PIXEL
	_label.pivot_offset = _label.size * 0.5
	_label.position = screen_position - _label.pivot_offset
	var source := CRTOverlay.get_active_pixelation_material(get_viewport())
	_pixelation.set_shader_parameter(&"pixel_size", source.get_shader_parameter(&"pixel_size") if source else 1.0)
	_pixelation.set_shader_parameter(&"chromatic_aberration_pixels",
		source.get_shader_parameter(&"chromatic_aberration_pixels") if source else 0.0)
	_label.show()
