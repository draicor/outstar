extends Control


# Request the server to change the movement speed
func _on_change_move_speed_button_down() -> void:
	# Only send the packet to update our speed if we are IDLE
	if GameManager.player_character.current_animation == GameManager.player_character.ASM.IDLE:
		Signals.ui_change_move_speed_button.emit()
