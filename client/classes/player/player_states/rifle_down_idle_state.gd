extends BaseState
class_name RifleDownIdleState


func _init() -> void:
	state_name = "rifle_down_idle"


func enter() -> void:
	player.player_movement.in_motion = false
	player.player_animator.switch_animation_library("rifle_down")
	player.player_animator.switch_animation("idle")
	# Clear crouching state
	player.is_crouching = false
	
	# Connect the ui hud signals for my local player character
	if player.is_local_player:
		if not player.ui_hud_weapon_slot_signals_connected:
			Signals.ui_hud_weapon_slot.connect(player.player_actions.queue_switch_weapon_action)
			player.ui_hud_weapon_slot_signals_connected = true


# We have to update rotations here so we can rotate towards our targets
func physics_update(delta: float) -> void:
	player.player_movement.handle_rotation(delta)


# Held inputs
func update(_delta: float) -> void:
	if ignore_input():
		return
	
	# Handle raise weapon
	if Input.is_action_pressed("right_click"):
		player.player_actions.queue_raise_weapon_action()
		return


func handle_input(event: InputEvent) -> void:
	if ignore_input():
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
		
		# If we didn't click on anything interactable
		else:
			# If we are not busy now
			if not player.is_busy:
				# Attempt to move to that cell (uses the action queue internally)
				player.handle_movement_click(mouse_position)
	
	# Reload rifle
	elif event.is_action_pressed("weapon_reload"):
		# We raise our weapon first, then reload
		player.player_actions.queue_raise_weapon_action()
		player.player_actions.queue_reload_weapon_action(
			player.player_equipment.get_current_weapon_max_ammo()
		)
	
	# Toggle weapon fire mode
	elif event.is_action_pressed("weapon_mode"):
		player.player_actions.queue_toggle_fire_mode_action()
	
	# Unequip rifle
	elif event.is_action_pressed("weapon_unequip"):
		player.player_actions.queue_switch_weapon_action(0)
	
	# Switch Weapon
	elif event.is_action_pressed("weapon_one"): # Unarmed
		player.player_actions.queue_switch_weapon_action(0)
	elif event.is_action_pressed("weapon_two"):
		player.player_actions.queue_switch_weapon_action(1)
	elif event.is_action_pressed("weapon_three"):
		player.player_actions.queue_switch_weapon_action(2)
	elif event.is_action_pressed("weapon_four"):
		player.player_actions.queue_switch_weapon_action(3)
	elif event.is_action_pressed("weapon_five"):
		player.player_actions.queue_switch_weapon_action(4)
	
	# Crouch toggle
	elif event.is_action_pressed("crouch"):
		player.player_actions.queue_enter_crouch_action()
