extends BaseState
class_name RifleAimIdleState

var last_target_point: Vector3 = Vector3.ZERO
var mouse_captured: bool = false


func _init() -> void:
	state_name = "rifle_aim_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("rifle_aim")
	player.player_animator.switch_animation("idle")
	# Enable aim rotation
	player.is_aim_rotating = true
	# Always reset dry_fired to false on state changes
	player.dry_fired = false
	
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
		broadcast_rotation_if_changed()
		player.set_mouse_cursor("default")
		# Restore the camera rotation step to default
		player.camera.ROTATION_STEP = player.camera.BASE_ROTATION_STEP
	
	# For local and remote players
	player.player_movement.is_rotating = false


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
			# Remove the vertical rotation
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
	
	# Handle lower weapon
	if not Input.is_action_pressed("right_click"):
		player.player_actions.queue_lower_weapon_action()
		return
	
	# Fire rifle if mouse isn't over the UI
	if Input.is_action_pressed("left_click") and not player.is_mouse_over_ui:
		# If we are still auto firing, prevent restarting it
		if player.is_auto_firing:
			return
		
		if player.player_equipment.get_fire_mode() == 1: # Automatic mode
			player.player_actions.queue_start_firing_action(
				player.player_equipment.get_current_ammo()
			)
		else: # Single fire mode
			var target: Vector3 = player.get_mouse_world_position()
			player.player_actions.queue_single_fire_action(target)
		return


# One-time inputs
func handle_input(event: InputEvent) -> void:
	if ignore_input():
		return
	
	# Track trigger release
	if event.is_action_released("left_click"):
		player.player_actions.queue_stop_firing_action(player.shots_fired)
	
	# Reload rifle
	elif event.is_action_pressed("weapon_reload"):
		player.player_actions.queue_reload_weapon_action(
			player.player_equipment.get_current_weapon_max_ammo()
		)
	
	# Toggle weapon fire mode
	elif event.is_action_pressed("weapon_mode"):
		player.player_actions.queue_toggle_fire_mode_action()
	
	# Crouch toggle
	elif event.is_action_pressed("crouch"):
		player.player_actions.queue_enter_crouch_action()
