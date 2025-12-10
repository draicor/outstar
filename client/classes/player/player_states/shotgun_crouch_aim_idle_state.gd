extends BaseState
class_name ShotgunCrouchAimIdleState

var last_target_point: Vector3 = Vector3.ZERO


func _init() -> void:
	state_name = "shotgun_crouch_aim_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("shotgun_crouch_aim")
	player.player_animator.switch_animation("idle")
	# Enable aim rotation
	player.is_aim_rotating = true
	# Always reset dry_fired to false on state changes
	player.dry_fired = false
	# Set crouching state
	player.is_crouching = true
	
	# Adjust the mouse click distance
	player.set_mouse_click_distance(player.mouse_distances.aim)
	
	# If this is our local player
	if player.is_local_player:
		player.set_mouse_cursor("crosshair")
		# Reduce the rotation step to minimum when aiming
		player.camera.ROTATION_STEP = 1.0
		# Store our model's Y rotation upon entering this state
		player.last_sent_rotation = player.model.rotation.y


func exit() -> void:
	# If this is our local player
	if player.is_local_player:
		player.set_mouse_cursor("default")
		# Restore the camera rotation step to default
		player.camera.ROTATION_STEP = player.camera.BASE_ROTATION_STEP
	
	# For local and remote players
	player.player_movement.is_rotating = false
	
	# Don't set is_crouching to false here because we might be transitioning to another crouch state


# Rotates the character on tick to match the mouse position
func physics_update(delta: float) -> void:
	# If we are leaving this state, don't rotate anymore
	if not player.is_aim_rotating:
		return
	
	if player.is_local_player:
		# Update the rotation sync timer
		player.rotation_sync_timer += delta
		
		# If it's time to send an update to the server
		if player.rotation_sync_timer > player.rotation_timer_interval:
			player.rotation_sync_timer = 0.0
			broadcast_rotation_if_changed()
		
		var target_point: Vector3 = player.get_mouse_world_position()
		
		# Only update if we have a valid target
		if target_point != Vector3.ZERO:
			# Calculate direction to target
			var direction: Vector3 = (target_point - player.global_position).normalized()
			
			# Remove the vertical direction
			direction.y = 0
			
			# Only update if direction is valid
			if direction.length_squared() > 0.01:
				# Update rotation target if it changed significantly
				if last_target_point.distance_to(target_point) > 0.01:
					player.player_movement.rotate_towards_direction(direction)
					last_target_point = target_point
	
	# We tick both local and remote characters here so we can rotate towards our target
	player.player_movement.handle_rotation(delta)


# Held inputs
func update(_delta: float) -> void:
	if ignore_input():
		return
	
	# Handle lower weapon (release right click) - transition to crouch down state
	if not Input.is_action_pressed("right_click"):
		broadcast_rotation_if_changed()
		player.player_actions.queue_lower_weapon_action()
		return
	
	# Fire shotgun if mouse isn't over the UI
	if Input.is_action_pressed("left_click") and not player.is_mouse_over_ui:
		# Fire weapon
		var target: Vector3 = player.get_mouse_world_position()
		player.player_actions.queue_multiple_fire_action([target])


# One-time inputs
func handle_input(event: InputEvent) -> void:
	if ignore_input():
		return
	
	# Reload shotgun
	elif event.is_action_pressed("weapon_reload"):
		# Check that we can reload (have spare ammo and we are not already at max ammo)
		if player.can_reload_weapon():
			player.player_actions.queue_reload_weapon_action(
				player.player_equipment.get_current_weapon_slot()
			)
	
	# Crouch toggle (leave crouch)
	elif event.is_action_pressed("crouch"):
		player.player_actions.queue_leave_crouch_action()
