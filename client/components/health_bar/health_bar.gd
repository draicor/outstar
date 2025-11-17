extends ProgressBar

@onready var damage_bar: ProgressBar = $DamageBar
@onready var damage_timer: Timer = $DamageTimer

var health: int = 0
var max_health: int = 0


func _ready() -> void:
	await get_tree().process_frame
	
	if not GameManager.player_character.is_local_player:
		return
	
	Signals.ui_update_health.connect(set_health)
	Signals.ui_update_max_health.connect(set_max_health)


# Start both bars full, matching the new health value
func init(spawn_health: int, spawn_max_health: int) -> void:
	# Store spawn values as internal variables
	health = spawn_health
	max_value = spawn_max_health
	
	# Update the health bar
	value = health
	# Update the damage bar
	damage_bar.max_value = health
	damage_bar.value = health
	
	print("_init_health: ", health)


func set_health(new_health: int) -> void:
	# Keep track of the current health
	# to determine if we decreased or increased our health
	var previous_health = health
	
	# Health shouldn't be greater than max health
	if new_health > max_health:
		health = max_health
	# Health shouldn't be negative
	elif new_health < 0:
		health = 0
	else:
		health = new_health
	
	value = health
	
	# If health decreased, update the damage bar
	if health < previous_health:
		damage_timer.start()
	
	# If health increased, immediately catch up
	else:
		# Damage bar catches up to the health bar
		damage_bar.value = health
	
	print("_set_health: ", health)


func set_max_health(new_max_health: int) -> void:
	max_health = new_max_health
	max_value = max_health
	
	# Decrease health if higher than max_health
	if health > max_health:
		health = max_health
	
	print("_set_max_health: ", health)


func _on_damage_timer_timeout() -> void:
	# Damage bar catches up to the health bar
	damage_bar.value = health
