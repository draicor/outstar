extends Control


@onready var respawn_button: Button = $PanelContainer/MarginContainer/RespawnButton

var respawn_timer: Timer


func _ready() -> void:
	hide()
	respawn_button.disabled = true
	
	# Initialize respawn timer if it doesn't exist
	if not respawn_timer:
		respawn_timer = Timer.new()
		respawn_timer.wait_time = 3.0 # 3 seconds before allowing respawning
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(_on_respawn_timer_timeout)
		add_child(respawn_timer)


func _on_respawn_timer_timeout() -> void:
	# Enable respawn button after timeout
	respawn_button.disabled = false


func _on_respawn_button_pressed() -> void:
	Signals.ui_respawn.emit()
	# Hide after pushing the respawn button
	toggle_menu(false)


func toggle_menu(show_menu: bool) -> void:
	respawn_button.disabled = true
	
	if show_menu:
		# Reveal the menu and start the countdown timer
		respawn_timer.start()
		show()
	else:
		# Stop timer and reset button
		respawn_timer.stop()
		hide()
