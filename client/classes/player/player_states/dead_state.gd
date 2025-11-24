extends BaseState
class_name DeadState


func _init() -> void:
	state_name = "dead"


func enter() -> void:
	player.player_movement.in_motion = false
	player.player_movement.autopilot_active = true # Disable movement
	# Clear any pending interactions
	player.interaction_target = null
	player.pending_interaction = null
	# Block other actions
	player.is_busy = true
	
	# Remove player from grid immediately on death
	RegionManager.remove_object(player.player_movement.grid_position)
	
	# Play death animation here
	# player.player_animator.switch_animation("death")
	
	# Disable collisions and add to exclude list
	player.disable_collisions()
	player.hide()
	
	# Disable weapon HUD if local player
	if player.is_local_player:
		player.player_equipment.hide_weapon_hud()


func exit() -> void:
	player.player_movement.autopilot_active = false
	player.is_busy = false
	
	# Re-enable collisions and remove from exclude list
	player.enable_collisions()
	player.show()
