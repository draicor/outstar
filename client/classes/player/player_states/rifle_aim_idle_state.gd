extends BaseState
class_name RifleAimIdleState

var last_target_point: Vector3 = Vector3.ZERO
var is_aim_rotating: bool = false
var mouse_captured: bool = false


func _init() -> void:
	state_name = "rifle_aim_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("rifle_aim")
	player.player_animator.switch_animation("idle")
	# Initialize with current mouse world position
	is_aim_rotating = true
	# Always reset dry_fired to false on state changes
	dry_fired = false
	
	# If this is our local player
	if player.player_state_machine.is_local_player:
		player.set_mouse_cursor("crosshair")
		# Reduce the rotation step to minimum when aiming
		player.camera.ROTATION_STEP = 1.0
		# Store our model's Y rotation upon entering this state
		last_sent_rotation = player.model.rotation.y


func exit() -> void:
	# If this is our local player
	if player.player_state_machine.is_local_player:
		broadcast_rotation_if_changed()
		player.set_mouse_cursor("default")
		# Restore the camera rotation step to default
		player.camera.ROTATION_STEP = player.camera.BASE_ROTATION_STEP
	
	# For local and remote players
	player.player_movement.is_rotating = false


# Rotates the character on tick to match the mouse position
func physics_update(delta: float) -> void:
	# If we are leaving this state, don't rotate anymore
	if not is_aim_rotating:
		return
	
	if is_local_player:
		# Update the rotation sync timer
		rotation_sync_timer += delta
		
		# If it's time to send an update to the server
		if rotation_sync_timer > rotation_timer_interval:
			rotation_sync_timer = 0.0
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
	# If we are busy, ignore input
	if player.is_busy:
		return
	# If we are in autopilot, ignore input
	if player.player_movement.autopilot_active:
		return
	
	# Handle lower weapon
	if not Input.is_action_pressed("right_click"):
		is_aim_rotating = false # Prevent rotation
		player.player_actions.queue_lower_weapon_action()
		return
	
	# Fire rifle if mouse isn't over the UI
	if Input.is_action_pressed("left_click") and not player.is_mouse_over_ui:
		# If we are still auto firing, prevent restarting it
		if is_auto_firing:
			return
		
		if player.player_equipment.get_fire_mode() == 1: # Automatic mode
			start_automatic_firing(true)
		else: # Single fire mode
			var target: Vector3 = player.get_mouse_world_position()
			single_fire(target, true)
		return


# One-time inputs
func handle_input(event: InputEvent) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# Track trigger release
	if event.is_action_released("left_click"):
		stop_automatic_firing(true)
		dry_fired = false
	
	# Reload rifle
	elif event.is_action_pressed("weapon_reload"):
		is_aim_rotating = false
		await reload_weapon_and_await(
			player.player_equipment.current_slot,
			player.player_equipment.get_current_weapon_max_ammo(),
			true
		)
		# If we are still holding right click, play the rifle aim idle animation
		if Input.is_action_pressed("right_click"):
			player.player_animator.switch_animation("idle")
			is_aim_rotating = true
	
	# Toggle weapon fire mode
	elif event.is_action_pressed("weapon_mode"):
		toggle_fire_mode(true)
