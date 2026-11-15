extends Node

const ARENA := preload("res://Levels/Arena.tscn")

var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(8.0).timeout.connect(func():
		push_error("Enemy hover test timed out")
		get_tree().quit(1)
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var arena := ARENA.instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var hover := arena.get_node("EnemyHover")
	hover.set_process(false)
	var camera := get_viewport().get_camera_3d()
	camera.set_process(false)
	var enemy: Enemy = arena.get_node("Enemies").get_child(0)
	var other: Enemy = arena.get_node("Enemies").get_child(1)
	await get_tree().create_timer(0.30).timeout

	var queue := enemy._ability_queue_ui
	var manager := arena.get_node("EnemyQueueVisibilityManager")
	var number: Label = enemy.get_node("ActionNumberUI/CanvasLayer/Number")
	var bar := enemy._health_bar
	var original_bar_position := bar.position
	var original_bar_scale := bar.scale
	var original_model_scale := enemy.mesh.scale
	var original_material := enemy.mesh.get_active_material(0)
	var original_overlay := StandardMaterial3D.new()
	enemy.mesh.material_overlay = original_overlay
	var origin := camera.unproject_position(enemy.mesh.global_position)
	var center := enemy.mesh.to_global(enemy.mesh.get_aabb().get_center())
	var point := camera.unproject_position(center)
	var bottom: AbilitySequenceItemUI = queue._items[enemy.ability_queue.peek_front_entry().id]
	var first_polygon := bottom.get_hex_screen_polygon()
	var baseline := maxf(first_polygon[3].y, number.get_rect().end.y)
	var pivot := Vector2(origin.x, baseline)
	var queue_offset := queue._screen_root.position - pivot
	var number_offset := number.get_rect().get_center() - pivot
	var backing := bar._backing.material_override as StandardMaterial3D
	var fill := bar._cells[0].material_override as StandardMaterial3D
	_check(not backing.no_depth_test and not fill.no_depth_test, "The normal health bar must respect occlusion")

	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 2.5, 0.4)
	wall.mesh = box
	arena.add_child(wall)
	var toward_camera := (camera.global_position - center).normalized()
	wall.global_transform = Transform3D(camera.global_basis, center + toward_camera * 3.0)
	hover.update_hover(point)
	_check(hover.hovered_enemy == enemy and enemy.is_model_hovered, "An occluded model must be hoverable")
	_check(enemy.mesh.material_overlay == Enemy.HOVER_MATERIAL, "The hovered model must draw the X-ray and outline")
	_check(enemy.mesh.get_active_material(0) == original_material, "Hover must preserve the model's base material")
	_check(backing.no_depth_test and fill.no_depth_test, "The highlighted health bar must draw through walls")
	_check(fill.render_priority > backing.render_priority, "The cells must draw over the backing")
	await get_tree().create_timer(0.18).timeout

	_check(is_equal_approx(enemy.hover_scale, 1.5), "Hover must settle at 150 percent")
	_check(queue._screen_root.position.is_equal_approx(pivot + queue_offset * 1.5), "Queue spacing must grow around the shared bottom edge")
	_check(queue._items_root.scale.is_equal_approx(Vector2.ONE * queue.queue_scale * 1.5), "Queue items must grow by 150 percent")
	var polygon := bottom.get_hex_screen_polygon()
	_check(polygon[0].is_equal_approx(pivot + (first_polygon[0] - pivot) * 1.5), "The overlap manager must see the scaled queue polygons")
	var number_center := number.get_global_transform_with_canvas() * (number.size * 0.5)
	_check(number_center.is_equal_approx(pivot + number_offset * 1.5), "The number must grow outward from the same pivot")
	var number_bottom := number.get_global_transform_with_canvas() * number.size
	_check(is_equal_approx(maxf(polygon[3].y, number_bottom.y), baseline), "The combined bottom edge must stay at its original height")
	_check(number.scale.is_equal_approx(Vector2.ONE * 1.5), "The number itself must grow by 150 percent")
	_check(bar.position.is_equal_approx(original_bar_position * Vector3(1.5, 1.0, 1.5)), "The bar must expand away from the model and keep its height")
	_check(bar.scale.is_equal_approx(original_bar_scale * Vector3(1.5, 1.0, 1.5)), "The world-space bar itself must grow by 150 percent")
	_check(enemy.mesh.scale.is_equal_approx(original_model_scale), "Hover must leave model size unchanged")

	enemy.health.damage(1)
	var damage := bar._damage_materials[0]
	_check(damage.shader == bar.DAMAGE_THROUGH_WALL_SHADER, "Highlighted damage fragments must also draw through walls")
	await get_tree().create_timer(0.06).timeout
	var progress: float = damage.get_shader_parameter("progress")

	# Place another model on the same camera ray and give it the lower world-Z priority.
	other.mesh.global_position = enemy.mesh.global_position + toward_camera * 0.65
	hover.update_hover(point)
	_check(hover.hovered_enemy == other and not enemy.is_model_hovered, "The nearest overlapping model must take over hover")
	_check(enemy.mesh.material_overlay == original_overlay, "Changing target must restore the previous overlay immediately")
	_check(not backing.no_depth_test and not fill.no_depth_test, "Changing target must restore health bar depth testing")
	_check(damage.shader == bar.DAMAGE_SHADER and is_equal_approx(damage.get_shader_parameter("progress"), progress), "Changing target must preserve the in-flight damage animation")
	await get_tree().create_timer(0.18).timeout
	_check(bar.position.is_equal_approx(original_bar_position) and bar.scale.is_equal_approx(original_bar_scale), "Unhovering must restore the authored health bar transform")
	manager.update_visibility(point)
	_check(other._ability_queue_ui._screen_root.z_index > queue._screen_root.z_index, "The hovered model's queue must draw in front")

	other.health.damage(other.health.max)
	_check(hover.hovered_enemy == null and other.mesh.material_overlay == null, "A dying enemy must immediately release hover")
	hover.update_hover(point)
	_check(hover.hovered_enemy == enemy, "A dying enemy must no longer intercept the ray")
	hover.update_hover(Vector2(-1, -1))
	_check(hover.hovered_enemy == null, "Leaving the viewport must release hover")

	print("ENEMY_HOVER_TEST_RESULT: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failures)")
	get_tree().quit(0 if _failures == 0 else 1)
