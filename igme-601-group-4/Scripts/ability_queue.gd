extends RefCounted
class_name AbilityQueue

## Non-visual queue with the same execution contract as AbilitySequenceUI.
signal queue_changed

var queue: Array[QueuedAbility] = []
var _next_entry_id: int = 1


func add_ability(ability: Ability, target: AbilityTarget) -> void:
	queue.append(QueuedAbility.new(_next_entry_id, ability, target))
	_next_entry_id += 1
	queue_changed.emit()

func clear_queue() -> void:
	queue.clear()
	queue_changed.emit()

func has_entries() -> bool:
	return not queue.is_empty()

func peek_front_entry() -> QueuedAbility:
	return queue.front() if has_entries() else null

func consume_entry(entry_id: int) -> bool:
	for index in range(queue.size()):
		if queue[index].id == entry_id:
			queue.remove_at(index)
			queue_changed.emit()
			return true
	return false

func size() -> int:
	return queue.size()

func copy(queue_to_copy:AbilityQueue) -> void:
	queue = queue_to_copy.queue.duplicate()
	_next_entry_id = queue_to_copy._next_entry_id
