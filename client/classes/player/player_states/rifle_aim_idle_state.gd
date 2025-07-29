extends BaseState
class_name RifleAimIdleState

var last_target_point: Vector3 = Vector3.ZERO
var is_aim_rotating: bool = false
var mouse_captured: bool = false


func _init() -> void:
	state_name = "rifle_aim_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("rifle_aim")
	player.player_animator.switch_animation("idle")
	player.set_mouse_cursor("crosshair")
	# Initialize with current mouse world position
	is_aim_rotating = true
	# Reduce the rotation step to minimum when aiming
	player.camera.ROTATION_STEP = 1.0


func exit() -> void:
	player.set_mouse_cursor("default")
	player.player_movement.is_rotating = false
	# Restore the camera rotation step to default
	player.camera.ROTATION_STEP = player.camera.BASE_ROTATION_STEP


# Rotates the character on tick to match the mouse position
func physics_update(delta: float) -> void:
	# If we are leaving this state, don't rotate anymore
	if not is_aim_rotating:
		return
	
	var target_point: Vector3 = player.get_mouse_world_position()
	
	# Only update if we have a valid target
	if target_point != Vector3.ZERO:
		# Calculate direction to target
		var direction: Vector3 = (target_point - player.global_position).normalized()
		# Remove the vertical rotation
		direction.y = 0
		
		# Only update if direction is valid
		if direction.length_squared() > 0.01:
			# Update rotation target if it changed significantly
			if last_target_point.distance_to(target_point) > 0.01:
				player.player_movement.rotate_towards_direction(direction)
				last_target_point = target_point
			
			# We tick handle_rotation here so we can rotate towards our target
			player.player_movement.handle_rotation(delta)


# Held inputs
func update(_delta: float) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# Handle lower weapon
	if not Input.is_action_pressed("right_click") and not player.is_busy:
		is_aim_rotating = false
		await player.player_animator.play_animation_and_await("rifle/rifle_aim_to_down", 3.5)
		player.player_state_machine.change_state("rifle_down_idle")
		return
	
	# Fire rifle if mouse isn't over the UI
	if Input.is_action_pressed("left_click") and not player.is_mouse_over_ui:
		_handle_firing()


# One-time inputs
func handle_input(event: InputEvent) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# Reload rifle
	elif event.is_action_pressed("weapon_reload"):
		is_aim_rotating = false
		await player.player_animator.play_animation_and_await("rifle/rifle_aim_reload_fast", 1.2)
		player.player_equipment.reload_equipped_weapon()
		
		# Do this only for my local character
		if player.my_player_character:
			Signals.ui_update_ammo.emit() # Update our ammo counter
		
		# If we are still holding right click, play the rifle aim idle animation
		if Input.is_action_pressed("right_click"):
			player.player_animator.switch_animation("idle")
			is_aim_rotating = true
	
	# Toggle weapon fire mode
	elif event.is_action_pressed("weapon_mode"):
		player.player_audio.play_projectile_rifle_mode_selector()
		player.player_equipment.toggle_weapon_fire_mode()


func _handle_firing() -> void:
	# If our mouse is somewhere valid (explicit check)
	var target_point: Vector3 = player.get_mouse_world_position()
	if target_point != Vector3.ZERO:
		player.player_equipment.calculate_weapon_direction(target_point)
		
		# Get the weapon data from the player equipment system
		var weapon = player.player_equipment.equipped_weapon
		var anim_name: String = weapon.get_animation()
		var play_rate: float = weapon.get_animation_play_rate()
		
		# Play the animation
		await player.player_animator.play_animation_and_await(anim_name, play_rate)
