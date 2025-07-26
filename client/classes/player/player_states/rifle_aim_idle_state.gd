extends BaseState
class_name RifleAimIdleState


func _init() -> void:
	state_name = "rifle_aim_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("rifle_aim")
	player.player_animator.switch_animation("idle")
	player.set_mouse_cursor("crosshair")


func exit() -> void:
	player.set_mouse_cursor("default")


# We have to update rotations here so we can rotate towards our targets
func physics_update(delta: float) -> void:
	player.player_movement.handle_rotation(delta)


# Held inputs
func update(_delta: float) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# Handle lower weapon
	if not Input.is_action_pressed("right_click") and not player.is_busy:
		await player.player_animator.play_animation_and_await("rifle/rifle_aim_to_down", 3.5)
		player.player_state_machine.change_state("rifle_down_idle")
		return
	
	# Fire rifle if mouse isn't over the UI
	if Input.is_action_pressed("left_click") and not player.is_mouse_over_ui:
		# Get the space point the mouse clicked on
		var mouse_position: Vector2 = player.get_viewport().get_mouse_position()
		var target_point: Vector3 = player.mouse_raycast(mouse_position)
		
		# If we clicked somewhere valid (explicit check)
		if target_point != Vector3.ZERO:
			# If our equipped weapon is not valid, abort
			if not player.player_equipment.equipped_weapon:
				return
			
			# Calculate direction from player to target point for rotation only
			var direction_to_target: Vector3 = (target_point - player.global_position).normalized()
			# Rotate towards target
			await player.player_movement.await_rotation(direction_to_target)
			
			# If we are NOT moving, calculate fire direction and fire
			if not player.player_movement.in_motion:
				player.player_equipment.calculate_weapon_direction(target_point)
				await player.player_animator.play_animation_and_await("rifle/rifle_aim_fire_single_fast")


# One-time inputs
func handle_input(event: InputEvent) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# Reload rifle
	if event.is_action_pressed("weapon_reload"):
		player.player_equipment.disable_left_hand_ik()
		await player.player_animator.play_animation_and_await("rifle/rifle_aim_reload_fast", 1.2)
		player.player_equipment.reload_equipped_weapon()
		
		# Do this only for my local character
		if player.my_player_character:
			Signals.ui_update_ammo.emit() # Update our ammo counter
		
		player.player_equipment.enable_left_hand_ik()
		# If we are still holding right click, play the rifle aim idle animation
		if Input.is_action_pressed("right_click"):
			player.player_animator.switch_animation("idle")
