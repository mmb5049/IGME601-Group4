extends Node2D
class_name AbilityDirectionEdgesUI

## This overlay deliberately keeps the default z_index. It is added after its
## hexagon's visual content, so it remains above its own icon while still
## respecting the complete front-to-back order of neighboring queue Items.
## A raised z_index here would let the glow escape its owning hexagon and draw
## over later Items or the drag preview.

const INNER_GREEN_TEXTURE := preload(
	"res://Arts/Textures/AbilityIndicator_GreenSign_Inner.png"
)
const INNER_GREEN_REGION := Rect2(71.0, 48.0, 220.0, 165.0)
# The source artwork is authored for the upper-left edge (Direction4), while
# the outer artwork's base orientation maps to Direction5. Rotating it by 60
# degrees puts both variants into the same reusable six-direction coordinate
# system. The offset below is the rotated correction for its alpha centroid.
const INNER_GREEN_ARTWORK_ROTATION := PI / 3.0
const INNER_GREEN_CENTER_OFFSET := Vector2(2.59, -5.23)

## Queue Items enable this so their glow stays inside each hexagon. The large
## targeting indicator leaves it disabled and keeps the outward-facing art.
@export var use_inner_green: bool = false

## Local-space distance that the queue-only artwork moves from each edge toward
## the hexagon center. At the queue Item's 0.72 scale, 11 local pixels become
## roughly 8 screen pixels, placing the glow just inside the blue frame.
@export_range(0.0, 24.0, 0.5, "suffix:px") var inner_edge_inset_pixels: float = 11.0

var _active_direction_index: int = -1
var _active_direction_is_legal: bool = true
var _all_directions_active: bool = false

@onready var _direction_edges: Array[DirectionSignUI] = [
	%Direction0 as DirectionSignUI,
	%Direction1 as DirectionSignUI,
	%Direction2 as DirectionSignUI,
	%Direction3 as DirectionSignUI,
	%Direction4 as DirectionSignUI,
	%Direction5 as DirectionSignUI,
]


func _ready() -> void:
	if use_inner_green:
		_apply_inner_green_artwork()
	hide_directions(false)


func _apply_inner_green_artwork() -> void:
	var inner_atlas := AtlasTexture.new()
	inner_atlas.atlas = INNER_GREEN_TEXTURE
	inner_atlas.region = INNER_GREEN_REGION
	for edge: DirectionSignUI in _direction_edges:
		# Every sign starts at an edge midpoint. Moving toward the shared origin
		# applies the same visual inset to vertical and diagonal sides.
		edge.position = edge.position.move_toward(
			Vector2.ZERO,
			inner_edge_inset_pixels
		)
		edge.set_green_artwork(
			inner_atlas,
			INNER_GREEN_CENTER_OFFSET,
			INNER_GREEN_ARTWORK_ROTATION
		)


func show_direction(direction_index: int, is_legal: bool, duration: float) -> void:
	if direction_index < 0 or direction_index >= _direction_edges.size():
		hide_directions(duration > 0.0, duration)
		return
	if (
		not _all_directions_active
		and direction_index == _active_direction_index
		and is_legal == _active_direction_is_legal
	):
		return

	_active_direction_index = direction_index
	_active_direction_is_legal = is_legal
	_all_directions_active = false
	for index in range(_direction_edges.size()):
		_direction_edges[index].set_direction_state(
			index == direction_index,
			is_legal,
			duration
		)


func show_all_directions(is_legal: bool, duration: float) -> void:
	if _all_directions_active and is_legal == _active_direction_is_legal:
		return

	_active_direction_index = -1
	_active_direction_is_legal = is_legal
	_all_directions_active = true
	for edge: DirectionSignUI in _direction_edges:
		edge.set_direction_state(true, is_legal, duration)


func hide_directions(animated: bool, duration: float = 0.0) -> void:
	_active_direction_index = -1
	_active_direction_is_legal = true
	_all_directions_active = false
	var applied_duration: float = duration if animated else 0.0
	for edge: DirectionSignUI in _direction_edges:
		edge.set_direction_state(false, true, applied_duration)
