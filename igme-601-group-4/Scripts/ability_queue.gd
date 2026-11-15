extends RefCounted
class_name AbilityQueue

## Non-visual queue with the same execution contract as AbilitySequenceUI.
signal queue_changed

var queued_entries: Array[QueuedAbility] = []
var _next_entry_id: int = 1


func add_ability(ability: Ability, target: AbilityTarget) -> void:
	queued_entries.append(QueuedAbility.new(_next_entry_id, ability, target))
	_next_entry_id += 1
	queue_changed.emit()


func clear_queue() -> void:
	queued_entries.clear()
	queue_changed.emit()


func has_entries() -> bool:
	return not queued_entries.is_empty()


func peek_front_entry() -> QueuedAbility:
	return queued_entries.front() if has_entries() else null


func consume_entry(entry_id: int) -> bool:
	for index in range(queued_entries.size()):
		if queued_entries[index].id == entry_id:
			queued_entries.remove_at(index)
			queue_changed.emit()
			return true
	return false
