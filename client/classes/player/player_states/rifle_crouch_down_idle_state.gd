extends BaseState
class_name RifleCrouchDownIdleState


func _init() -> void:
	state_name = "rifle_crouch_down_idle"


func enter() -> void:
	player.player_movement.in_motion = false
	player.player_animator.switch_animation_library("rifle_crouch_down")
	player.player_animator.switch_animation("idle")


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
	
	# Reload rifle
	if event.is_action_pressed("weapon_reload"):
		# We raise our weapon first (to crouch aim), then reload
		player.player_actions.queue_raise_weapon_action()
		player.player_actions.queue_reload_weapon_action(
			player.player_equipment.get_current_weapon_max_ammo()
		)
	
	# Toggle weapon fire mode
	elif event.is_action_pressed("weapon_mode"):
		player.player_actions.queue_toggle_fire_mode_action()
	
	# Crouch toggle (leave crouch)
	elif event.is_action_pressed("crouch"):
		player.player_actions.queue_leave_crouch_action()
