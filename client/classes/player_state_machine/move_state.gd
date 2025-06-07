extends BaseState
class_name MoveState

func _init() -> void:
	state_name = "move"

func enter() -> void:
	print("move state")
	# Determine animation based on player_speed
	var anim_state = "walk"
	match player.player_speed:
		2: anim_state = "jog"
		3: anim_state = "run"
	
	player._switch_locomotion(anim_state)

func physics_update(delta: float) -> void:
	player._handle_rotation(delta)
	player._process_movement_step(delta)
	
	# Check if movement is complete
	if not player.in_motion:
		finished.emit("idle")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		print("left click inside move state")
		if player.is_busy or player.autopilot_active:
			return
		
		var mouse_position: Vector2 = player.get_viewport().get_mouse_position()
		var target := player._get_mouse_click_target(mouse_position)
		
		if target:
			if target is Interactable:
				player._start_interaction(target)
			# Add other types of target classes later
		else:
			player._handle_movement_click(mouse_position)
	
	# Add other input later on
	# if event.is_action_pressed("right_click"):
