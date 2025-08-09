extends BaseState
class_name RifleAimIdleState

var last_target_point: Vector3 = Vector3.ZERO
var is_aim_rotating: bool = false
var mouse_captured: bool = false
var dry_fired: bool = false


func _init() -> void:
	state_name = "rifle_aim_idle"


func enter() -> void:
	player.player_animator.switch_animation_library("rifle_aim")
	player.player_animator.switch_animation("idle")
	player.set_mouse_cursor("crosshair")
	# Initialize with current mouse world position
	is_aim_rotating = true
	# Always reset dry_fired to false on state changes
	dry_fired = false
	
	# If this is our local player
	if player.player_state_machine.is_local_player:
		# Reduce the rotation step to minimum when aiming
		player.camera.ROTATION_STEP = 1.0


func exit() -> void:
	player.set_mouse_cursor("default")
	player.player_movement.is_rotating = false
	
	# If this is our local player
	if player.player_state_machine.is_local_player:
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
		# Play the lower weapon animation
		await player.player_animator.play_weapon_animation_and_await(
			"aim_to_down",
			"rifle"
		)
		player.player_state_machine.change_state("rifle_down_idle")
		return
	
	# Fire rifle if mouse isn't over the UI
	if Input.is_action_pressed("left_click") and not player.is_mouse_over_ui:
		handle_firing()


# One-time inputs
func handle_input(event: InputEvent) -> void:
	# If we are busy, ignore input
	if player.is_busy or player.player_movement.autopilot_active:
		return
	
	# Track trigger release
	if event.is_action_released("left_click"):
		dry_fired = false
	
	# Reload rifle
	elif event.is_action_pressed("weapon_reload"):
		is_aim_rotating = false
		await reload_weapon_and_await(
			player.player_equipment.current_slot,
			player.player_equipment.get_current_weapon_max_ammo(),
			true
		)
		
		# If we are still holding right click, play the rifle aim idle animation
		if Input.is_action_pressed("right_click"):
			player.player_animator.switch_animation("idle")
			is_aim_rotating = true
	
	# Toggle weapon fire mode
	elif event.is_action_pressed("weapon_mode"):
		player.player_audio.play_weapon_fire_mode_selector()
		player.player_equipment.toggle_fire_mode()


# CAUTION
# Move this to base_state once we add another weapon
func handle_firing() -> void:
	# Make sure our mouse is clicking somewhere valid
	var target_point: Vector3 = player.get_mouse_world_position()
	if target_point == Vector3.ZERO:
		return
	
	player.player_equipment.calculate_weapon_direction(target_point)
	# Get the weapon data from the player equipment system
	var weapon = player.player_equipment.equipped_weapon
	var anim_name: String = weapon.get_animation()
	var play_rate: float = weapon.get_animation_play_rate()
	
	# Check for an empty gun
	if not player.player_equipment.can_fire_weapon():
		if not dry_fired:
			dry_fired = true
			# Override play rate for dry fire (always use semi-auto speed)
			await player.player_animator.play_animation_and_await(anim_name, weapon.semi_fire_rate)
			# If after the animation ends our trigger is not pressed
			if not Input.is_action_pressed("left_click"):
				dry_fired = false
		# Abort here preventing shooting another round
		return
	
	# Play normal firing logic
	await player.player_animator.play_animation_and_await(anim_name, play_rate)
	# If after the animation ends our trigger is not pressed
	if not Input.is_action_pressed("left_click"):
		dry_fired = false
