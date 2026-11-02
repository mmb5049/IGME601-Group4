extends CanvasLayer

@export var player: PlayerController

@onready var health_bar: ProgressBar = $HealthBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var notification_panel: PanelContainer = $NotificationPanel
@onready var notification_label: Label = $NotificationPanel/NotificationLabel
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var mana_label: Label = $ManaBar/ManaLabel
var notification_id: int = 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as PlayerController
	
	notification_label.text = ""


	if player == null:
		push_error("HealthBar: Could not find PlayerController!")
		return

	player.health_changed.connect(_on_health_changed)
	player.mana_changed.connect(_on_mana_changed)
	player.notification_requested.connect(_on_notification_requested)
	
	# Initialize the health bar
	_on_health_changed(
		player.current_health,
		player.max_health
	)
	_on_mana_changed(player.current_mana, player.max_mana)


func _on_health_changed(
	current: int,
	maximum: int
) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]

func _on_mana_changed(current: int, maximum: int) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_label.text = "%d / %d" % [current, maximum]
	
func _on_notification_requested(message: String) -> void:
	notification_id += 1
	var current_id = notification_id

	notification_label.text = message
	notification_panel.visible = true

	await get_tree().create_timer(1.0).timeout

	# Only hide it if no newer notification appeared
	if current_id == notification_id:
		notification_panel.visible = false
