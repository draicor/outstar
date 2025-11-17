extends BaseState
class_name DeadState


func _init() -> void:
	state_name = "dead"


func enter() -> void:
	player.player_movement.in_motion = false
	player.player_movement.autopilot_active = true # Disable movement
	player.is_busy = true # Block other actions
	
	# Remove player from grid immediately on death
	RegionManager.remove_object(player.player_movement.grid_position)
	
	# Disable collisions and add to exclude list
	player.disable_collisions()
	player.hide()
	
	# Play death animation here
	# player.player_animator.switch_animation("death")
	
	# Disable weapon HUD if local player
	if player.is_local_player:
		player.player_equipment.hide_weapon_hud()
		# Show respawn UI here


func exit() -> void:
	player.player_movement.autopilot_active = false
	player.is_busy = false
	
	# Re-enable collisions and remove from exclude list
	player.enable_collisions()
	player.show()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn"):
		_handle_respawn_input()


func _handle_respawn_input() -> void:
	if player.is_local_player and not player.is_alive():
		player.player_packets.send_respawn_request_packet()
