extends ProgressBar

@onready var damage_bar: ProgressBar = $DamageBar
@onready var damage_timer: Timer = $DamageTimer

var current_health: int = 0
var current_max_health: int = 0


func _ready() -> void:
	print("=== HEALTH BAR READY ===")
	print("Health bar path: ", get_path())
	
	# Wait for the scene to be fully ready
	await get_tree().process_frame
	
	# Only connect if we have a valid local player
	if GameManager.player_character and GameManager.player_character.is_local_player:
		Signals.ui_update_health.connect(_on_ui_update_health)
		Signals.ui_update_max_health.connect(_on_ui_update_max_health)
		
		# Wait another frame to ensure everything is ready
		await get_tree().process_frame
		var local_player = GameManager.player_character
		if local_player:
			initialize(local_player.health, local_player.max_health)


# Start both bars full, matching the new health value
func initialize(health_value: int, max_health_value: int) -> void:
	print("=== HEALTH BAR INITIALIZE ===")
	print("health_value: ", health_value)
	print("max_health_value: ", max_health_value)

	# Store the values directly
	current_health = health_value
	current_max_health = max_health_value

	# Set the progress bar values
	max_value = current_max_health
	value = current_health

	# Set the damage bar values
	damage_bar.max_value = current_max_health
	damage_bar.value = current_health

	print("After initialize - current_health: ", current_health, " current_max_health: ", current_max_health)
	print("Progress bar value: ", value, " max_value: ", max_value)
	print("Damage bar value: ", damage_bar.value, " max_value: ", damage_bar.max_value)


func _on_ui_update_health(new_health: int) -> void:
	print("=== UI UPDATE HEALTH ===")
	print("Previous health: ", current_health)
	print("New health: ", new_health)
	print("Max health: ", current_max_health)
	
	var previous_health = current_health
	current_health = new_health
	
	# Clamp health to valid range
	if current_health < 0:
		current_health = 0
	elif current_health > current_max_health:
		current_health = current_max_health
	
	value = current_health
	
	print("Health after logic: ", current_health)
	
	# If health decreased, update the damage bar
	if current_health < previous_health:
		print("Health decreased, starting damage timer")
		damage_timer.start()
	# If health increased, immediately catch up
	elif current_health > previous_health:
		print("Health increased, updating damage bar")
		damage_bar.value = current_health
	
	print("Final health: ", current_health)


func _on_ui_update_max_health(new_max_health: int) -> void:
	print("=== UI UPDATE MAX HEALTH ===")
	print("Previous max_health: ", current_max_health)
	print("New max_health: ", new_max_health)
	
	current_max_health = new_max_health
	
	# Update both bars
	max_value = current_max_health
	damage_bar.max_value = current_max_health
	
	# Adjust health if it exceeds new max
	if current_health > current_max_health:
		current_health = current_max_health
		value = current_health
		damage_bar.value = current_health
	
	print("After update - current_health: ", current_health, " current_max_health: ", current_max_health)


func _on_damage_timer_timeout() -> void:
	# Damage bar catches up to the health bar
	damage_bar.value = current_health
	print("Damage timer timeout - damage bar set to: ", current_health)
