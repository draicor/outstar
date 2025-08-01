extends BaseState
class_name RifleDownIdleState


func _init() -> void:
	state_name = "rifle_down_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("rifle_down")
	player.player_animator.switch_animation("idle")
	
	# Do this only for my local character
	if player.my_player_character:
		# We update our ammo counter and then we display it
		Signals.ui_update_ammo.emit()
		Signals.ui_show_bottom_right_hud.emit()


# We have to update rotations here so we can rotate towards our targets
func physics_update(delta: float) -> void:
	player.player_movement.handle_rotation(delta)


# Held inputs
func update(_delta: float) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# Handle raise weapon
	if Input.is_action_pressed("right_click") and not player.is_busy and not player.is_mouse_over_ui:
		await player.player_animator.play_animation_and_await("rifle/rifle_down_to_aim", 2.5)
		player.player_state_machine.change_state("rifle_aim_idle")


func handle_input(event: InputEvent) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# If we left clicked to move BUT we weren't holding right click to start aiming
	if event.is_action_pressed("left_click"):
		# Get the mouse position and check what kind of target we have
		var mouse_position: Vector2 = player.get_viewport().get_mouse_position()
		var target: Object = player.get_mouse_click_target(mouse_position)
		
		# If we have a valid target, we try to determine what kind of class it is
		if target:
			if target is Interactable:
				player.start_interaction(target)
			# Add other types of target classes later
		
		# If we didn't click on anything interactable, then attempt to move to that cell
		else:
			player.handle_movement_click(mouse_position)
	
	# Reload rifle
	elif event.is_action_pressed("weapon_reload"):
		await player.player_animator.play_animation_and_await("rifle/rifle_down_to_aim", 2.5)
		await player.player_animator.play_animation_and_await("rifle/rifle_aim_reload_fast", 1.2)
		player.player_equipment.reload_equipped_weapon()
		
		# Do this only for my local character
		if player.my_player_character:
			Signals.ui_update_ammo.emit() # Update our ammo counter
		
		# If we are holding right click here, switch states
		if Input.is_action_pressed("right_click"):
			player.player_state_machine.change_state("rifle_aim_idle")
		# If we are NOT holding right click, lower the rifle and loop the rifle aim idle animation
		else:
			await player.player_animator.play_animation_and_await("rifle/rifle_aim_to_down", 3.5)
			player.player_animator.switch_animation("idle")
	
	# Toggle weapon fire mode
	elif event.is_action_pressed("weapon_mode"):
		player.player_audio.play_projectile_rifle_mode_selector()
		player.player_equipment.toggle_weapon_fire_mode()
	
	# Unequip rifle
	elif event.is_action_pressed("weapon_unequip"):
		await player.player_animator.play_animation_and_await("rifle/rifle_unequip", 1.3)
		player.player_equipment.unequip_weapon()
		player.player_state_machine.change_state("idle")
