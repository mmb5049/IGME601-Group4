extends Node3D

class_name Enemy

@export var movement:CharacterMovement
@export_category("Turn Planning")
@export var move_ability: Ability = preload("res://Abilities/Move.tres")
@export var attack_ability: Ability = preload("res://Abilities/Whirlwind.tres")
@export_range(1, 10) var minimum_actions: int = 2
@export_range(1, 10) var maximum_actions: int = 3

signal action_number_changed(number: int)

var action_number: int = 0:
	set(value):
		action_number = value
		action_number_changed.emit(value)
var ability_queue: AbilityQueue = AbilityQueue.new()
@onready var mesh:MeshInstance3D = $MeshInstance3D
var number_display = preload("res://Misc/number_display.tscn")

var health:int = 10

signal died()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("enemies")


## Override this method for enemy types with different planning rules.
func prepare_turn(player: PlayerController) -> void:
	ability_queue.clear_queue()
	if not is_instance_valid(player) or player.is_dead or health <= 0 or movement == null:
		return
	var planned_cell: Vector2i = movement.current_cell
	var player_cell: Vector2i = player.movement.current_cell
	for index in range(randi_range(minimum_actions, maxi(minimum_actions, maximum_actions))):
		var distance: int = HexGrid.hex_distance(planned_cell, player_cell)
		if attack_ability != null and distance >= 1 and distance <= attack_ability.range:
			var target := AbilityTarget.new(Global.TargetingType.ANNULAR)
			target.ring_radius = distance
			target.target_cells = HexGrid.get_ring(Vector2i.ZERO, distance)
			target.is_valid = true
			ability_queue.add_ability(attack_ability, target)
		elif move_ability != null:
			var direction: Vector2i = _approach_direction(planned_cell, player_cell)
			var target := AbilityTarget.new(move_ability.targeting_type)
			target.direction = direction
			target.is_valid = direction != Vector2i.ZERO
			ability_queue.add_ability(move_ability, target)
			planned_cell = _predict_move(planned_cell, direction)


## Search legal directional-move destinations for the shortest approach to
## an attack ring. Planning only predicts this enemy's movement; the player
## and other enemies stay at their preparation positions during prediction.
func _approach_direction(start: Vector2i, player_cell: Vector2i) -> Vector2i:
	if attack_ability == null:
		return _direction_toward(start, player_cell)
	var pending: Array[Vector2i] = [start]
	var first_directions: Dictionary[Vector2i, Vector2i] = {start: Vector2i.ZERO}
	var cursor: int = 0
	while cursor < pending.size():
		var cell: Vector2i = pending[cursor]
		cursor += 1
		for direction: Vector2i in HexGrid.DIRECTIONS:
			var destination: Vector2i = _predict_move(cell, direction)
			if first_directions.has(destination):
				continue
			var first: Vector2i = direction if cell == start else first_directions[cell]
			first_directions[destination] = first
			var distance: int = HexGrid.hex_distance(destination, player_cell)
			if distance >= 1 and distance <= attack_ability.range:
				return first
			pending.append(destination)
	return _direction_toward(start, player_cell)


func _predict_move(start: Vector2i, direction: Vector2i) -> Vector2i:
	var destination: Vector2i = start
	if direction == Vector2i.ZERO or move_ability == null:
		return destination
	for step in range(1, move_ability.range + 1):
		var cell: Vector2i = start + direction * step
		if not HexGrid.is_valid_cell(cell):
			break
		if HexGrid.is_occupied(cell) and HexGrid.occupied_cells[cell] != self:
			break
		destination = cell
	return destination


func _direction_toward(start: Vector2i, player_cell: Vector2i) -> Vector2i:
	var difference: Vector3 = (
		HexGrid.hex_to_world(player_cell) - HexGrid.hex_to_world(start)
	)
	var direction := Vector2i.ZERO
	var best_score: float = -INF
	for candidate: Vector2i in HexGrid.DIRECTIONS:
		var score: float = difference.normalized().dot(
			HexGrid.hex_to_world(candidate).normalized()
		)
		if score > best_score:
			best_score = score
			direction = candidate
	return direction if difference != Vector3.ZERO else Vector2i.ZERO


func execute_queued_ability(entry: QueuedAbility) -> bool:
	if health <= 0 or entry == null or entry.ability == null or entry.target == null:
		return false
	if not entry.target.is_valid:
		return false
	match entry.ability.type:
		Global.AbilityType.MOVEMENT:
			return await movement.execute_directional_move(entry.target.direction, entry.ability.range)
		Global.AbilityType.ATTACK:
			if entry.ability.presentation != null:
				if not await entry.ability.presentation.play(self, mesh, entry.target):
					return false
			if health <= 0 or is_queued_for_deletion():
				return false
			# Resolve around the actual execution position. Prepared plans do
			# not track or retarget a player who moved out of the selected ring.
			for cell in entry.target.resolve_cells(movement.current_cell):
				var victim: Node = HexGrid.occupied_cells.get(cell)
				if not is_instance_valid(victim):
					continue
				if victim == self or victim.is_queued_for_deletion():
					continue
				if victim is Enemy or victim is PlayerController:
					victim.damage(entry.ability.damage)
			return true
	return false

func damage(amount:int):
	if health <= 0:
		return
	health -= amount
	print("Enemy health is now: " + str(health))
	
	var new_display:Node3D = number_display.instantiate()
	get_parent().add_child(new_display)
	
	new_display.global_position = global_position + Vector3(0, 1.1, 0)
	new_display.set_number(-amount)

	mesh.flash()
	
	if health <= 0:
		die()

func die():
	HexGrid.set_occupied(movement.current_cell, false)
	died.emit()
	queue_free()
