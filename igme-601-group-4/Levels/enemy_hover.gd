extends Node

@onready var _arena: Node = get_parent()
@onready var _game_over: Control = _arena.get_node("%GameOver")

var hovered_enemy: Enemy
var _mouse_inside: bool = true


func _ready() -> void:
	# Use the updated camera, then publish the hover before the UI projects itself.
	process_priority = -5
	get_window().mouse_entered.connect(func(): _mouse_inside = true)
	get_window().mouse_exited.connect(func():
		_mouse_inside = false
		_set_hovered_enemy(null)
	)
	_game_over.visibility_changed.connect(func():
		if _game_over.visible:
			_set_hovered_enemy(null)
	)


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	if not _mouse_inside or _game_over.visible or viewport.gui_get_hovered_control() != null:
		_set_hovered_enemy(null)
		return
	update_hover(CRTOverlay.get_content_mouse_position(viewport))


func update_hover(mouse_position: Vector2) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null or not viewport.get_visible_rect().has_point(mouse_position):
		_set_hovered_enemy(null)
		return

	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var end := origin + direction * camera.far
	var closest := INF
	var target: Enemy
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not _arena.is_ancestor_of(enemy):
			continue
		var distance := enemy.get_hover_distance_squared(origin, end)
		if distance < closest or (is_finite(distance) and distance == closest and enemy == hovered_enemy):
			closest = distance
			target = enemy
	_set_hovered_enemy(target)


func _set_hovered_enemy(enemy: Enemy) -> void:
	if hovered_enemy == enemy:
		return
	if is_instance_valid(hovered_enemy):
		hovered_enemy.died.disconnect(_on_hovered_enemy_died)
		hovered_enemy.set_model_hovered(false)
	hovered_enemy = enemy
	if hovered_enemy != null:
		hovered_enemy.set_model_hovered(true)
		hovered_enemy.died.connect(_on_hovered_enemy_died)


func _on_hovered_enemy_died() -> void:
	_set_hovered_enemy(null)
