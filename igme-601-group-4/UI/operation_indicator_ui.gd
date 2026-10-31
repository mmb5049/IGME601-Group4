extends Control
class_name OperationIndicatorUI

## Duration used when a direction sign appears, disappears, or changes between
## the supplied legal (green) and illegal (red) artwork.
@export_range(0.01, 0.5, 0.01, "suffix:s") var edge_transition_duration: float = 0.12

var _current_ability: Ability
@onready var _ability_display: AbilityHexDisplayUI = %AbilityDisplay
@onready var _direction_edges: AbilityDirectionEdgesUI = %DirectionEdges


func _ready() -> void:
	_direction_edges.hide_directions(false)
	visible = false


func show_targeting(ability: Ability) -> void:
	if ability == null:
		return

	_current_ability = ability
	_ability_display.set_ability(ability)
	_direction_edges.hide_directions(false)
	visible = true


## DIRECTION highlights one edge. SINGLE_TILE and ANNULAR surround the entire
## indicator because they select tiles rather than an orientation.
func set_target_preview(target: AbilityTarget) -> void:
	if _current_ability == null or target == null:
		_direction_edges.hide_directions(true, edge_transition_duration)
		return

	match _current_ability.targeting_type:
		Global.TargetingType.DIRECTION:
			var direction_index: int = HexGrid.DIRECTIONS.find(target.direction)
			if direction_index < 0:
				_direction_edges.hide_directions(true, edge_transition_duration)
				return

			# AbilityTarget keeps the hovered direction even when a future gameplay
			# rule marks it invalid, allowing that edge to crossfade green to red.
			_direction_edges.show_direction(
				direction_index,
				target.is_valid,
				edge_transition_duration
			)

		Global.TargetingType.SINGLE_TILE, Global.TargetingType.ANNULAR:
			_direction_edges.show_all_directions(
				target.is_valid,
				edge_transition_duration
			)

		_:
			_direction_edges.hide_directions(true, edge_transition_duration)


func hide_indicator() -> void:
	_current_ability = null
	_direction_edges.hide_directions(false)
	visible = false


func get_display_global_position() -> Vector2:
	return _ability_display.global_position


func get_display_global_scale() -> Vector2:
	return _ability_display.global_scale
