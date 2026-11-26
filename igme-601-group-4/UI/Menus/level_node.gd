@tool
extends Area3D
class_name LevelNode

## Inactive levels stay visible and cannot be entered.
@export var active: bool = true:
	set(value):
		active = value
		_refresh_display()
## A stable identifier for this level.
@export var level_id: StringName:
	set(value):
		level_id = value
		update_configuration_warnings()

@export var previous_level: LevelNode
@export var next_levels: Array[LevelNode] = []
@export var level_name: String:
	set(value):
		level_name = value
		_refresh_display()
@export var level_scene: PackedScene:
	set(value):
		level_scene = value
		update_configuration_warnings()

@export_group("Colors")
@export var active_accent: Color = Color("58d8c9"):
	set(value):
		active_accent = value
		_refresh_display()
@export var hover_accent: Color = Color("a5fff2"):
	set(value):
		hover_accent = value
		_refresh_display()
@export var inactive_accent: Color = Color("4d646a"):
	set(value):
		inactive_accent = value
		_refresh_display()
@export var active_text_color: Color = Color("e0f9f7"):
	set(value):
		active_text_color = value
		_refresh_display()
@export var inactive_text_color: Color = Color("8ca1a6"):
	set(value):
		inactive_text_color = value
		_refresh_display()

@onready var _accent: StandardMaterial3D = $Rim.material_override
@onready var _label: Label3D = $LevelName

var _hovered: bool = false


func _ready() -> void:
	_refresh_display()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if level_id.is_empty():
		warnings.append("Set a level ID.")
	if level_name.strip_edges().is_empty():
		warnings.append("Set a level name.")
	if active and level_scene == null:
		warnings.append("Assign a scene to this active level.")
	return warnings


func _refresh_display() -> void:
	if not is_node_ready():
		return
	_accent.albedo_color = inactive_accent
	if active:
		_accent.albedo_color = hover_accent if _hovered else active_accent
	_label.text = level_name
	_label.modulate = active_text_color if active else inactive_text_color
	update_configuration_warnings()


func _mouse_enter() -> void:
	_hovered = true
	_refresh_display()


func _mouse_exit() -> void:
	_hovered = false
	_refresh_display()


func _input_event(_camera: Camera3D, event: InputEvent, _hit: Vector3,
		_normal: Vector3, _shape_index: int) -> void:
	if Engine.is_editor_hint() or not active or level_scene == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var new_scene:ArenaManager = level_scene.instantiate()
		new_scene.current_level = level_id
		Global.switch_scenes(new_scene)
