extends BaseState
class_name RifleAimIdleState


func _init() -> void:
	state_name = "rifle_aim_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("rifle_aim")
	player.player_animator.switch_animation("idle")


# We have to update rotations here so we can rotate towards our targets
func physics_update(delta: float) -> void:
	player._handle_rotation(delta)


# Held inputs
func update(_delta: float) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.autopilot_active:
		return
	
	# Fire rifle if mouse isn't over the UI
	if Input.is_action_pressed("right_click") and not player.is_mouse_over_ui:
		# Get the space point the mouse clicked on
		var mouse_position: Vector2 = player.get_viewport().get_mouse_position()
		var target_point: Vector3 = player._mouse_raycast(mouse_position)
		
		# If we clicked somewhere valid (explicit check)
		if target_point != Vector3.ZERO:
			# Calculate direction from player to target point
			var direction_to_target: Vector3 = (target_point - player.global_position).normalized()
			# Rotate towards it and then fire
			await player.await_rotation(direction_to_target)
			# If we are NOT moving, fire
			if not player.in_motion:
				await player.player_animator.play_animation_and_await("rifle/rifle_aim_fire_single_fast")


# One-time inputs
func handle_input(event: InputEvent) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.autopilot_active:
		return
	
	if event.is_action_pressed("left_click"):
		# Get the mouse position and check what kind of target we have
		var mouse_position: Vector2 = player.get_viewport().get_mouse_position()
		var target := player._get_mouse_click_target(mouse_position)
		
		# If we have a valid target, we try to determine what kind of class it is
		if target:
			if target is Interactable:
				player._start_interaction(target)
			# Add other types of target classes later
		
		# If we didn't click on anything interactable, then attempt to move to that cell
		else:
			player._handle_movement_click(mouse_position)
	
	# Reload rifle
	elif event.is_action_pressed("weapon_reload"):
		player.player_equipment.disable_left_hand_ik()
		await player.player_animator.play_animation_and_await("rifle/rifle_aim_reload_fast")
		player.player_equipment.reload_equipped_weapon()
		Signals.ui_update_ammo.emit() # Update our ammo counter
		player.player_equipment.enable_left_hand_ik()
	
	# Lower rifle
	elif event.is_action_pressed("weapon_rifle") or event.is_action_pressed("weapon_unequip"):
		await player.player_animator.play_animation_and_await("rifle/rifle_aim_to_down", 2.0)
		player.player_state_machine.change_state("rifle_down_idle")
