extends Node3D

class_name Enemy

@export var movement:CharacterMovement
@onready var mesh:MeshInstance3D = $Pivot/Skeleton3D/Cube
@export_category("Turn Planning")
@export var move_ability: Ability = preload("res://Abilities/Move.tres")
@export var attack_ability: Ability = preload("res://Abilities/Whirlwind.tres")
@export_range(1, 10) var minimum_actions: int = 2
@export_range(1, 10) var maximum_actions: int = 3

const OVERHEAD_UI_RISE: float = 28.0
const EnemyHealthBar := preload("res://Characters/enemy_health_bar.gd")
const HOVER_MATERIAL := preload("res://Materials/enemy_hover.tres")
const HOVER_SCALE: float = 1.5
const HOVER_TRANSITION: float = 0.12
# Body and head regions in fractions of the unscaled mesh bounds.
const HOVER_REGIONS: Array[AABB] = [
	AABB(Vector3(0.04, 0.02, 0.08), Vector3(0.92, 0.64, 0.84)),
	AABB(Vector3(0.16, 0.57, 0.04), Vector3(0.68, 0.43, 0.92)),
]

signal action_number_changed(number: int)
signal died
signal death_animation_finished

var action_number: int = 0:
	set(value):
		action_number = value
		action_number_changed.emit(value)
var ability_queue: AbilityQueue = AbilityQueue.new()
var number_display = preload("res://Misc/number_display.tscn")
var _dying: bool = false
var is_model_hovered: bool = false
var hover_scale: float = 1.0
var _hover_progress: float = 0.0
var _normal_overlay: Material

@onready var health:Health = $Health
@onready var _health_bar: EnemyHealthBar = $HealthBar
@onready var _ability_queue_ui: EnemyAbilityQueueUI = get_node_or_null("EnemyAbilityQueueUI")
@onready var _action_number_label: Label = get_node_or_null("ActionNumberUI/CanvasLayer/Number")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("enemies")
	_health_bar.bind_health(health)
	health.died.connect(die)
	process_priority = -4
	set_process(false)


func get_hover_distance_squared(ray_start: Vector3, ray_end: Vector3) -> float:
	if health.is_dead or is_queued_for_deletion() or not mesh.is_visible_in_tree() or mesh.mesh == null:
		return INF
	var to_mesh := mesh.global_transform.affine_inverse()
	var local_start := to_mesh * ray_start
	var local_end := to_mesh * ray_end
	var bounds := mesh.get_aabb()
	var closest := INF
	for region in HOVER_REGIONS:
		var hitbox := AABB(bounds.position + bounds.size * region.position, bounds.size * region.size)
		var hit: Variant = hitbox.intersects_segment(local_start, local_end)
		if hit != null:
			closest = minf(closest, ray_start.distance_squared_to(mesh.to_global(hit)))
	return closest


func set_model_hovered(hovered: bool) -> void:
	if is_model_hovered == hovered:
		return
	is_model_hovered = hovered
	if hovered:
		_normal_overlay = mesh.material_overlay
		mesh.material_overlay = HOVER_MATERIAL
	else:
		mesh.material_overlay = _normal_overlay
	_health_bar.set_show_through_walls(hovered)
	set_process(true)


func _process(delta: float) -> void:
	var target := 1.0 if is_model_hovered else 0.0
	_hover_progress = move_toward(_hover_progress, target, delta / HOVER_TRANSITION)
	hover_scale = lerpf(1.0, HOVER_SCALE, smoothstep(0.0, 1.0, _hover_progress))
	_health_bar.set_hover_scale(hover_scale, to_local(mesh.global_position))
	if _hover_progress == 0.0 and not is_model_hovered:
		set_process(false)


func scale_overhead_position(camera: Camera3D, anchor: Vector2, offset: Vector2 = Vector2.ZERO) -> Vector2:
	var point := anchor + offset
	if hover_scale == 1.0:
		return point
	var bottom := -INF
	if is_instance_valid(_ability_queue_ui):
		bottom = _ability_queue_ui.get_rest_bottom_offset()
	if is_instance_valid(_action_number_label) and action_number > 0:
		bottom = maxf(bottom, _action_number_label.size.y * 0.5)
	# Keep the shared bottom edge fixed while retaining the model as the horizontal pivot.
	var pivot := anchor
	pivot.y += bottom if is_finite(bottom) else 0.0
	if not camera.is_position_behind(mesh.global_position):
		pivot.x = camera.unproject_position(mesh.global_position).x
	return pivot.lerp(point, hover_scale)


func get_overhead_screen_position(camera: Camera3D) -> Vector2:
	if not is_instance_valid(mesh) or mesh.mesh == null:
		return Vector2.INF
	# The mesh transform includes import scale and any movement from ability effects.
	var center := mesh.to_global(mesh.get_aabb().get_center())
	if camera.is_position_behind(center):
		return Vector2.INF
	var overhead_position := camera.unproject_position(center) - Vector2(0.0, OVERHEAD_UI_RISE)
	# Center the number and the queue's fixed bottom slot as a pair.
	if is_instance_valid(_ability_queue_ui):
		overhead_position.x -= _ability_queue_ui.screen_offset.x * 0.5
	return overhead_position


## Override this method for enemy types with different planning rules.
func prepare_turn(player: PlayerController) -> void:
	ability_queue.clear_queue()
	if not is_instance_valid(player) or player.health.is_dead or health.is_dead or movement == null:
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
	if health.is_dead or entry == null or entry.ability == null or entry.target == null:
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
			if health.is_dead or is_queued_for_deletion():
				return false
			# Resolve around the actual execution position. Prepared plans do
			# not track or retarget a player who moved out of the selected ring.
			for cell in entry.target.resolve_cells(movement.current_cell):
				# A target may have been freed while presentation was awaiting.
				# Keep the raw Variant until validated: assigning a freed instance
				# to a typed Node fails before is_instance_valid can run.
				var victim: Variant = HexGrid.occupied_cells.get(cell)
				if not is_instance_valid(victim):
					continue
				if victim == self or victim.is_queued_for_deletion():
					continue
				if victim is PlayerController:
					victim.health.damage(entry.ability.damage)
				else:
					print(victim)
			return true
	return false

func die() -> void:
	if _dying:
		return
	_dying = true
	var lethal_hit := health.is_dead
	health.is_dead = true
	set_model_hovered(false)
	if HexGrid.occupied_cells.get(movement.current_cell) == self:
		HexGrid.set_occupied(movement.current_cell, false)
	$Pivot.hide()
	died.emit()
	if lethal_hit and _health_bar.is_animating_damage():
		await _health_bar.damage_animation_finished
	queue_free()
	death_animation_finished.emit()
