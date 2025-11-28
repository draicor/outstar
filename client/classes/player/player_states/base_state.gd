extends Node
class_name BaseState

signal finished(next_state_name)

var player_state_machine: PlayerStateMachine = null
var player: Player = null
var state_name: String = "unnamed_state"


func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass


# Called on physics_update to check if we need to broadcast the rotation update
func broadcast_rotation_if_changed():
	# Check if the rotation changed significantly
	var current_rotation: float = player.model.rotation.y
	if abs(current_rotation - player.last_sent_rotation) >= player.ROTATION_CHANGE_THRESHOLD:
		player.last_sent_rotation = current_rotation
		player.player_packets.send_rotate_character_packet(current_rotation)


# Returns true if this character has its weapon down
func is_weapon_down_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_down_idle":
			return true
		"rifle_crouch_down_idle":
			return true
		_:
			return false


# Returns true if this character has its weapon up
func is_weapon_aim_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_aim_idle":
			return true
		"rifle_crouch_aim_idle":
			return true
		_:
			return false


# Tries to fire the next round (live or dry fire) in automatic fire mode
func next_automatic_fire() -> void:
	# If we are not firing anymore, abort
	if not player.is_auto_firing:
		return
	
	# If not in automatic fire mode, abort
	if player.player_equipment.get_fire_mode() != 1:
		return
	
	# For remote players, check if we've reached the expected shot count, abort
	if not player.is_local_player and player.expected_shots_fired >= 0 and player.shots_fired >= player.expected_shots_fired:
		player.is_auto_firing = false
		player.expected_shots_fired = -1
		return
	
	# Get the weapon data from the player equipment system
	var weapon = player.player_equipment.equipped_weapon
	var anim_name: String = weapon.get_animation()
	var play_rate: float = weapon.get_animation_play_rate()
	
	# Check for an empty gun
	if not player.player_equipment.can_fire_weapon():
		# If we haven't dry fired yet, then this shot will be our ONLY dry fire shot
		if not player.dry_fired:
			player.dry_fired = true
			# Override play rate for dry fire (always use semi-auto speed)
			await player.player_animator.play_animation_and_await(anim_name, weapon.semi_fire_rate)
			
			# After dry firing once, automatically stop trying to fire
			if player.is_local_player:
				# Check for trigger release during the animation
				if not Input.is_action_pressed("left_click"):
					player.player_actions.queue_stop_firing_action(player.shots_fired)
					player.dry_fired = false
			
			# Remote players
			else:
				player.is_auto_firing = false
				player.dry_fired = false
		
		# Return here to prevent shooting a live round after the dry fire
		return
	
	# If we have ammo, fire live round
	await player.player_animator.play_animation_and_await(anim_name, play_rate)
	# Increase our local firing counter to keep track of how many bullets we have fired
	player.shots_fired += 1
	
	if player.is_local_player:
		# Check if weapon is inside wall after each shot
		if player.player_equipment.equipped_weapon.is_weapon_inside_wall():
			# Weapon is inside wall, immediately queue a stop firing action
			player.player_actions.queue_stop_firing_action(player.shots_fired)
			player.dry_fired = false
			return
		
		# If we are still holding the left click, continue firing
		if Input.is_action_pressed("left_click"):
			next_automatic_fire()
		# Check for trigger release during the animation
		else:
			# Only queue stop_firing if we're not already stopping
			if player.is_auto_firing:
				player.player_actions.queue_stop_firing_action(player.shots_fired)
			player.dry_fired = false
	
	# For remote players, continue firing until we reach expected_shots_fired
	else:
		# Check if we should continue firing
		if player.is_auto_firing:
			# If we don't know how many shots to take
			# OR
			# If we know the expected shot count and we haven't reached it yet, continue firing
			if player.expected_shots_fired < 0 or player.shots_fired < player.expected_shots_fired:
				next_automatic_fire()
			else:
				# Stop firing
				player.is_auto_firing = false
				player.expected_shots_fired = -1


# Helper function to skip input if one of these is valid
func ignore_input() -> bool:
	if player.is_busy:
		return true
	if player.player_movement.autopilot_active:
		return true
	if player.is_mouse_over_ui:
		return true
	
	return false
