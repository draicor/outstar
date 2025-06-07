extends BaseState
class_name IdleState

func _init() -> void:
	state_name = "idle"

func enter() -> void:
	print("idle state")
	player._switch_locomotion("idle")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		print("left click inside idle state")
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
