extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var notification_panel: PanelContainer = $NotificationPanel
@onready var notification_label: Label = $NotificationPanel/NotificationLabel
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var mana_label: Label = $ManaBar/ManaLabel
@onready var health_damage_bar: ProgressBar = $HealthWhiteBar
@onready var mana_damage_bar: ProgressBar = $ManaWhiteBar
var health_tween: Tween
var mana_tween: Tween
var notification_id: int = 0

func _ready() -> void:
	await get_parent().last_scene_done
	var player := get_parent().get_node_or_null("Player") as PlayerController
	
	notification_label.text = ""


	if player == null:
		push_error("HealthBar: Could not find PlayerController!")
		return

	player.health.changed.connect(_on_health_changed)
	player.mana_changed.connect(_on_mana_changed)
	player.notification_requested.connect(_on_notification_requested)
	
	# Initialize the health bar
	_on_health_changed(
		player.health.current,
		player.health.max
	)
	_on_mana_changed(player.current_mana, player.max_mana)
	
	health_damage_bar.max_value = player.health.max
	health_damage_bar.value = player.health.current

	mana_damage_bar.max_value = player.max_mana
	mana_damage_bar.value = player.current_mana
	
func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_label.text = "%d / %d" % [current, maximum]

	health_damage_bar.max_value = maximum

	animate_bar(health_bar, health_damage_bar, current, true)

func _on_mana_changed(current: int, maximum: int) -> void:
	mana_bar.max_value = maximum
	mana_label.text = "%d / %d" % [current, maximum]

	mana_damage_bar.max_value = maximum

	animate_bar(mana_bar, mana_damage_bar, current, false)
	
	
func _on_notification_requested(message: String) -> void:
	notification_id += 1
	var current_id = notification_id

	notification_label.text = message
	notification_panel.visible = true

	await get_tree().create_timer(1.0).timeout

	# Only hide it if no newer notification appeared
	if current_id == notification_id:
		notification_panel.visible = false

func animate_bar(
	main_bar: ProgressBar,
	white_bar: ProgressBar,
	target_value: float,
	is_health: bool
) -> void:
	var current_value = main_bar.value

	var tween: Tween

	if is_health:
		tween = health_tween
	else:
		tween = mana_tween

	# Stop previous animation
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()

	if target_value < current_value:
		# DAMAGE / MANA CONSUMPTION
		# Main bar updates immediately
		main_bar.value = target_value

		# White bar slowly follows
		tween.tween_property(
			white_bar,
			"value",
			target_value,
			0.8
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	else:
		# HEALING / MANA REGENERATION
		# White bar updates immediately
		white_bar.value = target_value

		# Main bar slowly catches up
		tween.tween_property(
			main_bar,
			"value",
			target_value,
			0.8
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Save tween reference
	if is_health:
		health_tween = tween
	else:
		mana_tween = tween
