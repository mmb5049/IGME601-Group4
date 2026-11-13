extends Node

const ARENA := preload("res://Levels/Arena.tscn")

var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(8.0).timeout.connect(func():
		push_error("Enemy health bar test timed out")
		get_tree().quit(1)
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _fragments(bar: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in bar.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			result.append(child)
	return result


func _run() -> void:
	var arena := ARENA.instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await get_tree().process_frame
	var controller: ActionExecutionController = arena.get_node("ActionExecutionController")
	var enemies := arena.get_node("Enemies").get_children()
	var enemy: Enemy = enemies[0]
	var bar := enemy._health_bar
	_check(bar.get_parent() == enemy, "The health bar must be an enemy's world-space child")
	_check(bar._cells.size() == enemy.health.max, "Full health must create one cell per HP")

	enemy.movement.set_pos(Vector2i(2, 1))
	var bar_position := bar.global_position
	var enemy_position := enemy.global_position
	_check(await enemy.movement.execute_directional_move(Vector2i(1, 0), 1), "Enemy must move one tile")
	_check(
		(bar.global_position - bar_position).is_equal_approx(enemy.global_position - enemy_position),
		"The bar must follow the enemy across the board"
	)
	bar_position = bar.global_position
	enemy.mesh.global_position += Vector3.UP
	_check(bar.global_position.is_equal_approx(bar_position), "Model-only effects must leave the bar at the tile")

	enemy.health.max = 6
	enemy.health.heal(1)
	_check(bar._cells.size() == 6, "A maximum health change must update the number of cells")
	enemy.health.damage(2)
	_check(bar._cells[3].visible and not bar._cells[4].visible and not bar._cells[5].visible, "Damage must consume the rightmost cells")
	var first := _fragments(bar)
	_check(first.size() == 2, "Both lost cells must start animating together")
	_check(first[0].mesh == bar._cells[4].mesh and first[1].mesh == bar._cells[5].mesh, "Damage fragments must start at the lost cells")

	await get_tree().create_timer(0.10).timeout
	var material: ShaderMaterial = first[0].material_override
	var progress: float = material.get_shader_parameter("progress")
	_check(progress > 0.0 and progress < 1.0, "Damage animation must advance over time")
	enemy.health.damage(1)
	_check(_fragments(bar).size() == 3, "A second hit must start before the first finishes")
	await get_tree().create_timer(0.15).timeout
	_check(_fragments(bar).size() == 1, "The first hit must finish on its own schedule")
	await bar.damage_animation_finished
	await get_tree().process_frame
	_check(_fragments(bar).is_empty(), "All finished damage fragments must be freed")

	enemy.health.heal(1)
	_check(bar._cells[3].visible, "Healing must refill a cell")
	enemy.movement.set_pos(Vector2i(2, 1))
	var trap_cell := Vector2i(3, 1)
	var trap: Trap = preload("res://Abilities/Trap.tscn").instantiate()
	arena.add_child(trap)
	trap.setup(HexGrid, trap_cell, 100)
	trap.is_spawning = false
	HexGrid.traps[trap_cell] = trap
	var target := AbilityTarget.new(Global.TargetingType.DIRECTION)
	target.direction = Vector2i(1, 0)
	target.is_valid = true
	var queue := AbilityQueue.new()
	queue.add_ability(enemy.move_ability, target)
	_check(not await controller.execute_next(enemy, queue), "A lethal trap must resolve the pending move as interrupted")
	_check(not queue.has_entries(), "A lethal trap must allow the scheduler to consume the move")
	_check(enemy.health.is_dead and not HexGrid.is_occupied(trap_cell), "Death must release the cell immediately")
	_check(not enemy.mesh.is_visible_in_tree() and not enemy.movement.is_moving, "Death must hide the model and stop movement immediately")
	_check(bar.is_animating_damage() and _fragments(bar).size() == 4, "Overkill must animate the four remaining cells")

	var game_over: GameOver = arena.get_node("%GameOver")
	for index in range(1, enemies.size()):
		enemies[index].health.damage(100)
	_check(not game_over.visible, "The victory screen must wait for the final death animation")
	await enemies.back().death_animation_finished
	_check(game_over.visible and game_over.win_screen.visible, "Victory must appear after all death animations")
	await get_tree().process_frame
	_check(not is_instance_valid(enemy), "The enemy and bar must be freed after the fade")

	print("ENEMY_HEALTH_BAR_TEST_RESULT: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failures)")
	get_tree().quit(0 if _failures == 0 else 1)
