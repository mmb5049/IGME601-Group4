extends CanvasLayer
class_name CRTOverlay

const VIEWPORT_KEY := &"crt_overlay"

var _forwarded_event: InputEventMouse
@onready var _screen: ColorRect = $Screen
@onready var _pixelation_layer: CanvasLayer = $PixelationLayer


func _ready() -> void:
	get_viewport().set_meta(VIEWPORT_KEY, self)
	# When CRT is placed behind the UI, keep both passes behind it.
	_pixelation_layer.layer = mini(_pixelation_layer.layer, layer - 1)
	visibility_changed.connect(_sync_pixelation_visibility)
	_sync_pixelation_visibility()


func _sync_pixelation_visibility() -> void:
	_pixelation_layer.visible = visible


func _exit_tree() -> void:
	if _get_overlay(get_viewport()) == self:
		get_viewport().remove_meta(VIEWPORT_KEY)


static func get_content_mouse_position(viewport: Viewport) -> Vector2:
	var overlay := _get_overlay(viewport)
	if is_instance_valid(overlay) and overlay._forwarded_event != null:
		return overlay._forwarded_event.position
	var mouse_position := viewport.get_mouse_position()
	if is_instance_valid(overlay):
		return overlay._map_to_content(mouse_position, overlay._get_curvature())
	return mouse_position


static func is_forwarding_mouse(viewport: Viewport) -> bool:
	var overlay := _get_overlay(viewport)
	return is_instance_valid(overlay) and overlay._forwarded_event != null


static func _get_overlay(viewport: Viewport) -> CRTOverlay:
	if viewport.has_meta(VIEWPORT_KEY):
		return viewport.get_meta(VIEWPORT_KEY) as CRTOverlay
	return null


func _get_curvature() -> float:
	if not visible or not _screen.is_visible_in_tree():
		return 0.0
	var material := _screen.material as ShaderMaterial
	return float(material.get_shader_parameter(&"curvature_strength"))


func _map_to_content(point: Vector2, curvature: float) -> Vector2:
	var bounds := get_viewport().get_visible_rect()
	var centered := (point - bounds.position) / bounds.size * 2.0 - Vector2.ONE
	var cross_axis := Vector2(centered.y, centered.x)
	var curved := centered * (Vector2.ONE + curvature * cross_axis * cross_axis)
	return bounds.position + (curved + Vector2.ONE) * 0.5 * bounds.size


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null or mouse == _forwarded_event:
		return
	var curvature := _get_curvature()
	if curvature == 0.0:
		return

	# Dispatch the source coordinates through Godot's regular GUI and targeting
	# input paths. Keep the active event available to code that polls the mouse.
	var viewport := get_viewport()
	var previous_event := _forwarded_event
	var remapped := mouse.duplicate() as InputEventMouse
	remapped.position = _map_to_content(mouse.position, curvature)
	remapped.global_position = remapped.position
	if remapped is InputEventMouseMotion:
		var motion := remapped as InputEventMouseMotion
		motion.relative = remapped.position - _map_to_content(
			mouse.position - motion.relative, curvature
		)
	_forwarded_event = remapped
	viewport.push_input(remapped, true)
	_forwarded_event = previous_event
	viewport.set_input_as_handled()
