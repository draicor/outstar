extends BaseState
class_name RifleDownIdleState


func _init() -> void:
	state_name = "rifle_down_idle"


func enter() -> void:
	player.set_equipped_weapon_type("rifle")
	player.player_animator.switch_animation_library("rifle_down")
	player.player_animator.switch_animation("idle")


# We have to update rotations here so we can rotate towards our targets
func physics_update(delta: float) -> void:
	player._handle_rotation(delta)


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
	
	# Raise rifle
	elif event.is_action_pressed("weapon_rifle") or event.is_action_pressed("right_click"):
		await player.player_animator.play_animation_and_await("rifle/rifle_down_to_aim")
		player.player_state_machine.change_state("rifle_aim_idle")
	
	# Unequip rifle
	elif event.is_action_pressed("weapon_unequip"):
		await player.player_animator.play_animation_and_await("rifle/rifle_unequip", 1.2)
		player.player_state_machine.change_state("idle")
