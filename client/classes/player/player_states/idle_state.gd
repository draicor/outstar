extends BaseState
class_name IdleState


func _init() -> void:
	state_name = "idle"


func enter() -> void:
	# Switch our locomotion depending on our player's gender
	player.player_animator.switch_animation_library(player.gender)
	player.player_animator.switch_animation("idle")
	
	# Do this only for my local character
	if player.my_player_character:
		Signals.ui_hide_bottom_right_hud.emit()


# We have to update rotations here so we can rotate towards our targets
func physics_update(delta: float) -> void:
	player.player_movement.handle_rotation(delta)


func handle_input(event: InputEvent) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
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
		
		# If we didn't click on anything interactable, then attempt to move to that cell
		else:
			player.handle_movement_click(mouse_position)
	
	# Weapon equip
	elif event.is_action_pressed("weapon_one"):
		switch_weapon("m16_rifle")
	elif event.is_action_pressed("weapon_two"):
		switch_weapon("akm_rifle")
	elif event.is_action_pressed("weapon_three"):
		print("Trying to equip weapon 3")
	elif event.is_action_pressed("weapon_four"):
		print("Trying to equip weapon 4")
	elif event.is_action_pressed("weapon_five"):
		print("Trying to equip weapon 5")


func switch_weapon(weapon_name: String) -> void:
	# Unequip weapon if equipped
	if player.player_equipment.equipped_weapon:
		# CAUTION this should be more flexible
		await player.player_animator.play_animation_and_await("rifle/rifle_unequip", 1.3)
		player.player_equipment.unequip_weapon()
	
	# Equip weapon one
	player.player_equipment.equip_weapon(weapon_name) # CAUTION set this to work with weapon slots
	await player.player_animator.play_animation_and_await("rifle/rifle_equip", 1.3)
	player.player_state_machine.change_state("rifle_down_idle")
