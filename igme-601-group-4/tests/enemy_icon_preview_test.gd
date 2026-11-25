extends Node

const ARENA := preload("res://Levels/Arena.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")
	get_tree().create_timer(8.0).timeout.connect(func(): get_tree().quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var arena := ARENA.instantiate() as ArenaManager
	arena.current_level = &"3"
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await get_tree().create_timer(0.4).timeout
	var controller: ActionExecutionController = arena.get_node("ActionExecutionController")
	var player := controller.player_actor
	var enemy := arena.enemies[0]
	controller.action_order.erase(enemy)
	controller.action_order.insert(1, enemy)
	var queue := enemy._ability_queue_ui
	var manager := arena.get_node("EnemyQueueVisibilityManager")
	manager.set_process(false)
	arena.get_node("EnemyHover").set_process(false)
	var direction := AbilityTarget.new(Global.TargetingType.DIRECTION)
	direction.is_valid = true
	player.movement.set_pos(Vector2i.ZERO)
	for step in HexGrid.DIRECTIONS:
		if not HexGrid.is_occupied(step) and HexGrid.is_valid_cell(step):
			direction.direction = step
			break
	player.ability_queue.add_ability(player.get_ability("Move"), direction)
	var first := enemy.ability_queue.peek_front_entry()
	var item: AbilitySequenceItemUI = queue._items[first.id]
	var point := item.get_hex_global_position()
	manager.update_visibility(point)
	check(controller.preview_actor == enemy, "Hover must preview the icon owner")
	check(enemy.is_model_hovered and enemy._ghost_mesh.material_overlay == Enemy.HOVER_MATERIAL, "The visible enemy must highlight")
	check(player.hologram.movement.current_cell == direction.direction, "The first enemy acts after the first player move")
	check(player.hologram.visible and player.movement.current_cell == Vector2i.ZERO, "Only the player hologram should move")
	check(enemy.ability_queue.peek_front_entry() == first and player.ability_queue.size() == 1, "Preview must preserve live queues")
	await get_tree().create_timer(0.25).timeout
	manager.update_visibility(point)
	check(controller.preview_actor == enemy and queue.entry_index_at(point) == 0, "Hover must survive enlargement")
	if enemy.ability_queue.size() > 1:
		var next: AbilitySequenceItemUI = queue._items[enemy.ability_queue.queue[1].id]
		manager.update_visibility(next.get_hex_global_position())
		check(enemy.hologram.ability_queue.peek_front_entry() == enemy.ability_queue.queue[1], "Switching icons must simulate the preceding round")
	manager.update_visibility(Vector2(-1000, -1000))
	check(not enemy.is_model_hovered and not player.hologram.visible and player.mesh.visible, "Exiting must restore live visuals")
	var second_enemy := controller.action_order[2] as Enemy
	controller.preview_queue(0, second_enemy)
	check(enemy.hologram.ability_queue.size() == enemy.ability_queue.size() - 1, "Earlier enemies must act before the selected enemy")
	check(second_enemy.hologram.ability_queue.size() == second_enemy.ability_queue.size(), "The selected enemy action must remain pending")
	controller.preview_queue(0)
	check(player.hologram.movement.current_cell == Vector2i.ZERO, "Player preview must still stop before its own action")
	player.clear_preview()
	player.request_ability(player.get_ability("Move"))
	manager.update_visibility(item.get_hex_global_position())
	check(controller.preview_actor == enemy, "Targeting must allow inspecting an enemy")
	manager.update_visibility(Vector2(-1000, -1000))
	check(controller.preview_actor == player and player.current_mode == PlayerController.PlayerMode.TARGETING, "Leaving must restore targeting")
	player.cancel_targeting()
	print("ENEMY_ICON_PREVIEW: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
