extends Node2D
class_name DirectionSignUI

## Each direction sign contains both supplied artworks. Fading the layers
## independently preserves their authored glow and avoids recoloring artifacts.
var _state_is_active: bool = false
var _state_is_legal: bool = true
var _state_tween: Tween

@onready var _green_sign: Sprite2D = %GreenSign
@onready var _red_sign: Sprite2D = %RedSign


func _ready() -> void:
	_apply_state(false, true, 0.0)


## Allows queue overlays to replace only the legal artwork while retaining the
## shared red layer and fade logic used by the large operation indicator.
func set_green_artwork(
	texture: Texture2D,
	visual_center_offset: Vector2,
	artwork_rotation: float = 0.0
) -> void:
	if texture == null:
		return
	_green_sign.texture = texture
	_green_sign.position = visual_center_offset
	_green_sign.rotation = artwork_rotation


## Shows green for a legal direction, red for an illegal direction, or hides
## both layers when this edge is not the direction currently under the cursor.
func set_direction_state(active: bool, is_legal: bool, duration: float) -> void:
	if active == _state_is_active and is_legal == _state_is_legal:
		return
	_apply_state(active, is_legal, duration)


func _apply_state(active: bool, is_legal: bool, duration: float) -> void:
	_state_is_active = active
	_state_is_legal = is_legal

	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()

	var green_target := Color(1.0, 1.0, 1.0, 1.0 if active and is_legal else 0.0)
	var red_target := Color(1.0, 1.0, 1.0, 1.0 if active and not is_legal else 0.0)
	if duration <= 0.0:
		_green_sign.modulate = green_target
		_red_sign.modulate = red_target
		return

	_state_tween = create_tween()
	_state_tween.set_parallel(true)
	_state_tween.set_trans(Tween.TRANS_QUAD)
	_state_tween.set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(_green_sign, "modulate", green_target, duration)
	_state_tween.tween_property(_red_sign, "modulate", red_target, duration)
