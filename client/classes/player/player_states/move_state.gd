extends BaseState
class_name MoveState


# We only have a move_state, no matter what weapon we have equipped
# because when moving, can't really do anything else, we only transition
# to other states, we just update the animation library and use the same move state


func _init() -> void:
	state_name = "move"


func enter() -> void:
	# Adjust the mouse click distance
	player.set_mouse_click_distance(player.mouse_distances.idle)


# _physics_process runs at a fixed timestep
# Movement should be handled here because this runs before _process
func physics_update(delta: float) -> void:
	player.player_movement.handle_rotation(delta)
	player.player_movement.process_movement_step(delta)


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
			# Clear any pending interactions
			player.interaction_target = null
			player.pending_interaction = null
	
			# Attempt to move to that cell (uses the action queue internally)
			player.handle_movement_click(mouse_position)
