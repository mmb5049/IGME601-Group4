extends Node

var failures: int = 0
var player: PlayerController


func _ready() -> void:
	run.call_deferred()
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func screen_cell(cell: Vector2i) -> Vector2:
	return player.camera.unproject_position(HexGrid.to_global(HexGrid.hex_to_world(cell)))


func run() -> void:
	var arena: Node = load("res://Levels/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	var controller: ActionExecutionController = arena.get_node("ActionExecutionController")
	await controller.preparation_started
	player = controller.player_actor
	# Exercise the actual gameplay resource, not just a synthetic Annular
	# ability: a Single Tile configuration would otherwise pass API tests.
	var whirlwind: Ability = load("res://Abilities/Whirlwind.tres")
	check(whirlwind.targeting_type == Global.TargetingType.ANNULAR, "Whirlwind must use Annular targeting")
	player.request_ability(whirlwind)
	var first_ring: Array[Vector2i] = HexGrid.get_ring(player.movement.current_cell, 1)
	for hovered_cell in first_ring:
		player.cursor_position = screen_cell(hovered_cell)
		player._update_targeting_preview()
		for ring_cell in first_ring:
			check(HexGrid.cell_meshes[ring_cell].material_override == HexGrid.material_select, "Whirlwind must highlight all six tiles for every hovered first-ring tile")
	player.cancel_targeting()
	var ability := Ability.new()
	ability.ability_name = "Annular test"
	ability.targeting_type = Global.TargetingType.ANNULAR
	ability.type = Global.AbilityType.ATTACK
	ability.range = 1
	ability.cost = 10
	ability.damage = 3
	ability.icon = load("res://Arts/Textures/Move.png")
	var first: AbilityTarget = player.evaluate_target(ability, screen_cell(Vector2i(1, 0)))
	check(first.is_valid and first.ring_radius == 1 and first.target_cells.size() == 6, "Range 1 must select the full first ring")
	check(not player.evaluate_target(ability, screen_cell(Vector2i.ZERO)).is_valid, "Player's own tile must not select a ring")
	check(not player.evaluate_target(ability, screen_cell(Vector2i(2, 0))).is_valid, "Ring outside Range must be invalid")
	check(not player.evaluate_target(ability, screen_cell(Vector2i(5, 0))).is_valid, "Off-board mouse position must be invalid")
	ability.range = 2
	var second: AbilityTarget = player.evaluate_target(ability, screen_cell(Vector2i(2, 0)))
	check(second.is_valid and second.ring_radius == 2 and second.target_cells.size() == 12, "Range 2 must allow selection of the second ring")
	check(player.evaluate_target(ability, screen_cell(Vector2i(1, 0))).ring_radius == 1, "Range 2 must still allow the first ring")
	check(first.ring_radius == 1 and first.target_cells.size() == 6, "Later previews must not overwrite earlier targets")
	for cell in second.resolve_cells(Vector2i.ZERO):
		check(HexGrid.hex_distance(Vector2i.ZERO, cell) == 2, "Only the chosen ring is targeted, excluding inner tiles")
	ability.range = 0
	check(not player.evaluate_target(ability, screen_cell(Vector2i(1, 0))).is_valid, "Range 0 must not allow an annular target")
	ability.range = 2
	player.request_ability(ability)
	player.cursor_position = screen_cell(Vector2i(2, 0))
	player._update_targeting_preview()
	for cell in HexGrid.get_ring(Vector2i.ZERO, 2):
		check(HexGrid.cell_meshes[cell].material_override == HexGrid.material_select, "Preview must highlight the entire hovered ring")
	for cell in HexGrid.get_ring(Vector2i.ZERO, 1):
		check(HexGrid.cell_meshes[cell].material_override == HexGrid.material_attack, "Other eligible rings must keep their range highlight")
	var indicator: OperationIndicatorUI = arena.get_node("GlobalUIRoot/SwayLayer/ActionDockUI/OperationIndicatorUI")
	check(indicator._direction_edges._all_directions_active, "Annular selector must show surrounding validity feedback")
	if "--capture-annular" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../annular-preview.png")
	player.cancel_targeting()

	# At the arena corner, the stored ring remains complete but resolution
	# clips invalid tiles; moving before execution recenters the same ring.
	player.movement.set_pos(Vector2i(4, 0))
	ability.range = 1
	var edge: AbilityTarget = player.evaluate_target(ability, screen_cell(Vector2i(3, 0)))
	check(edge.is_valid and edge.target_cells.size() == 6, "Edge selection must preserve the relative ring")
	check(edge.resolve_cells(player.movement.current_cell).size() == 3, "Edge resolution must exclude off-board cells")
	player.movement.set_pos(Vector2i.ZERO)
	check(edge.resolve_cells(player.movement.current_cell).size() == 6, "Queued ring must resolve around the actor's current position")

	var enemies: Array[Node] = arena.get_node("Enemies").get_children()
	var positions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(3, -1)]
	for index in range(enemies.size()):
		enemies[index].movement.set_pos(positions[index])
	player.request_ability(ability)
	player.cursor_position = screen_cell(Vector2i(1, 0))
	var mana_before: int = player.current_mana
	player._confirm_current_target()
	check(player.current_mana == mana_before - ability.cost, "Confirming an entire ring must pay cost only once")
	check(controller.player_queue.queued_entries.size() == 1, "Ring confirmation must create one queue entry")
	check(controller.player_queue.peek_front_entry().target.target_cells.size() == 6, "Queue must preserve all target offsets")
	await controller.execute_next(player, controller.player_queue)
	check(enemies[0].health == 7 and enemies[1].health == 7, "Every enemy on the chosen ring must take damage exactly once")
	check(enemies[2].health == 10 and enemies[3].health == 10, "Enemies outside the chosen ring must remain unaffected")
	check(not controller.player_queue.has_entries(), "Entire ring must consume a single ability entry")
	var single := ability.duplicate() as Ability
	single.targeting_type = Global.TargetingType.SINGLE_TILE
	single.range = 2
	await player.execute_ability(single, player.evaluate_target(single, screen_cell(Vector2i(2, 0))))
	check(enemies[2].health == 7 and enemies[0].health == 7, "Existing single-tile attack must still damage only one target")

	ability.type = Global.AbilityType.TRAP
	await player.execute_ability(ability, first)
	check(HexGrid.traps.size() == 6, "Annular traps must be placed on every ring tile")
	print("ANNULAR_TEST_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)
