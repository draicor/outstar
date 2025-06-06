class_name UnarmedState
extends PlayerState

enum MovementState { IDLE, WALK, JOG, RUN, INTERACTING }
var current_movement_state: MovementState = MovementState.IDLE


func enter() -> void:
	player.play_animation("idle")


func physics_update(delta: float) -> void:
	# Handle movement state transitions
	handle_movement_state()
	
	# Existing movement processing
	if player.in_motion:
		player._process_movement_step(delta)


func handle_movement_state() -> void:
	var new_state: MovementState
	
	if player.current_animation == player.ASM.INTERACTING:
		new_state = MovementState.INTERACTING
	elif player.in_motion:
		match player.player_speed:
			1: new_state = MovementState.WALK
			2: new_state = MovementState.JOG
			_: new_state = MovementState.RUN
	else:
		new_state = MovementState.IDLE
	
	if new_state != current_movement_state:
		current_movement_state = new_state
		update_animation()


func update_animation() -> void:
	match current_movement_state:
		MovementState.IDLE:
			player.play_animation("idle")
		MovementState.WALK:
			player.play_animation("walk")
		MovementState.JOG:
			player.play_animation("jog")
		MovementState.RUN:
			player.play_animation("run")
		MovementState.INTERACTING:
			# Keep interacting animation
			pass


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		if player.is_busy or player.autopilot_active:
			return
		
		var mouse_position := player.get_viewport().get_mouse_position()
		var target := player._get_mouse_click_target(mouse_position)
		
		if target is Interactable:
			player._start_interaction(target)
		else:
			player._handle_movement_click(mouse_position)
