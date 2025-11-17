extends Control

@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	Signals.player_character_spawned.connect(_handle_signal_player_character_spawned)
	hide()


func _handle_signal_player_character_spawned() -> void:
	if not GameManager.player_character:
		return
	
	var local_player: Player = GameManager.player_character
	
	health_bar.init(local_player.health, local_player.max_health)
	show()
