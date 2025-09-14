extends BaseState
class_name IdleState


func _init() -> void:
	state_name = "idle"


func enter() -> void:
	player.player_movement.in_motion = false
	# Switch our locomotion depending on our player's gender
	player.player_animator.switch_animation_library(player.gender)
	player.player_animator.switch_animation("idle")
	
	# Only connect these signals for my local player character, once
	if is_local_player:
		if not signals_connected:
			Signals.ui_hud_weapon_slot.connect(switch_weapon)
			signals_connected = true


# We have to update rotations here so we can rotate towards our targets
func physics_update(delta: float) -> void:
	player.player_movement.handle_rotation(delta)


func handle_input(event: InputEvent) -> void:
	if ignore_input():
		return
	
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
			# Attempt to move to that cell (uses the action queue internally)
			player.handle_movement_click(mouse_position)


	# Weapon equip
	elif event.is_action_pressed("weapon_one"): # Unarmed
		switch_weapon(0, true)
	elif event.is_action_pressed("weapon_two"):
		switch_weapon(1, true)
	elif event.is_action_pressed("weapon_three"):
		switch_weapon(2, true)
	elif event.is_action_pressed("weapon_four"):
		switch_weapon(3, true)
	elif event.is_action_pressed("weapon_five"):
		switch_weapon(4, true)
