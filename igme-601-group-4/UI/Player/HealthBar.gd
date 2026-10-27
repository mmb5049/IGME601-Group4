extends CanvasLayer

@export var player: PlayerController

@onready var health_bar: ProgressBar = $ProgressBar


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as PlayerController

	if player == null:
		push_error("HealthBar: Could not find PlayerController!")
		return

	player.health_changed.connect(_on_health_changed)

	# Initialize the health bar
	_on_health_changed(
		player.current_health,
		player.max_health
	)


func _on_health_changed(
	current: int,
	maximum: int
) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
