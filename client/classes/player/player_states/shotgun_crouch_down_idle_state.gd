extends BaseState
class_name ShotgunCrouchDownIdleState


func _init() -> void:
	state_name = "shotgun_crouch_down_idle"


func enter() -> void:
	player.player_movement.in_motion = false
	player.player_animator.switch_animation_library("shotgun_crouch_down")
	player.player_animator.switch_animation("idle")
	# Set crouching state
	player.is_crouching = true
	
	# Adjust the mouse click distance
	player.set_mouse_click_distance(player.mouse_distances.idle)
	
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
	
	# Handle raise weapon (right click) - transition to crouch aim state
	if Input.is_action_pressed("right_click"):
		player.player_actions.queue_raise_weapon_action()
		return


# One-time inputs
func handle_input(event: InputEvent) -> void:
	if ignore_input():
		return
	
	# If we left clicked to move
	if event.is_action_pressed("left_click"):
		# Get the mouse position and check what kind of target we have
		var mouse_position: Vector2 = player.get_viewport().get_mouse_position()
		var target: Object = player.get_mouse_click_target(mouse_position)
		
		# If we have a valid target, we try to determine what kind of class it is
		if target:
			if target is Interactable:
				# Leave crouch, then interact
				player.player_actions.queue_leave_crouch_action()
				# The interaction will be handled after leaving crouch
				player.pending_interaction = target
			# Add other types of target classes later
		
		# If we didn't click on anything interactable
		else:
			# Clear any pending interactions
			player.interaction_target = null
			player.pending_interaction = null
			
			# Remember we need to crouch after movement
			player.player_movement.should_crouch_after_movement = true
			# Leave crouch, then move, then re-enter crouch at destination
			player.player_actions.queue_leave_crouch_action()
			# Store the destination for movement after leaving crouch
			var destination: Vector2i = Utils.local_to_map(player.get_mouse_world_position())
			player.player_movement.grid_destination = destination
		return
	
	# Reload shotgun
	elif event.is_action_pressed("weapon_reload"):
		# Check that we can reload (have spare ammo and we are not already at max ammo)
		if player.can_reload_weapon():
			# We raise our weapon first (to crouch aim), then reload
			player.player_actions.queue_raise_weapon_action()
			player.player_actions.queue_reload_weapon_action(
				player.player_equipment.get_current_weapon_slot()
			)
	
	# Crouch toggle (leave crouch)
	elif event.is_action_pressed("crouch"):
		player.player_actions.queue_leave_crouch_action()
