extends BaseState
class_name MoveState


func _init() -> void:
	state_name = "move"
	Signals.player_update_locomotion_animation.connect(_update_locomotion_animation)


func enter() -> void:
	print("move state")


# _physics_process runs at a fixed timestep
# Movement should be handled here because this runs before _process
func physics_update(delta: float) -> void:
	player._handle_rotation(delta)
	player._process_movement_step(delta)


func _update_locomotion_animation(cells_to_move: int) -> void:
	# Determine animation based on player_speed
	var anim_state = "walk"
	match cells_to_move:
		2: anim_state = "jog"
		3: anim_state = "run"
	
	player.switch_animation(anim_state)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		# If we are busy, ignore input
		if player.is_busy or player.autopilot_active:
			return
		
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
	
	# Add other input later on
	# if event.is_action_pressed("right_click"):
