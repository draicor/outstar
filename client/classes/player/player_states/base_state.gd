extends Node
class_name BaseState

signal finished(next_state_name)

var player_state_machine: PlayerStateMachine = null
var player: Player = null
var state_name: String = "unnamed_state"
var is_local_player: bool = false # set to true for local player
var signals_connected: bool = false # to only do this once
# Rotation broadcast logic
# 1 second for idle aim and 0.5 seconds for automatic firing
const AIM_ROTATION_INTERVAL: float = 1.0
const FIRING_ROTATION_INTERVAL: float = 0.5
var rotation_sync_timer: float = 0.0
var last_sent_rotation: float = 0.0
var rotation_timer_interval: float = AIM_ROTATION_INTERVAL
const ROTATION_CHANGE_THRESHOLD: float = 0.1 # radians
var is_aim_rotating: bool = false
# Weapon firing
var dry_fired: bool = false
# Firearm automatic firing
var is_auto_firing: bool = false
var is_trying_to_syncronize: bool = false
var shots_fired: int = 0
var server_shots_fired: int = 0


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
	if abs(current_rotation - last_sent_rotation) >= ROTATION_CHANGE_THRESHOLD:
		last_sent_rotation = current_rotation
		player.player_packets.send_rotate_character_packet(current_rotation)


# Returns true if this character has its weapon down
func is_weapon_down_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_down_idle":
			return true
		_:
			return false


# Returns true if this character has its weapon up
func is_weapon_aim_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_aim_idle":
			return true
		_:
			return false


# Tries to fire the next round (live or dry fire) in automatic fire mode,
func next_automatic_fire() -> void:
	# If we are not firing anymore, abort
	if not is_auto_firing:
		return
	
	# If not in automatic fire mode, abort
	if player.player_equipment.get_fire_mode() != 1:
		return
	
	# Get the weapon data from the player equipment system
	var weapon = player.player_equipment.equipped_weapon
	var anim_name: String = weapon.get_animation()
	var play_rate: float = weapon.get_animation_play_rate()
	
	# Check for an empty gun
	if not player.player_equipment.can_fire_weapon():
		# If we haven't dry fired yet, then this shot will be our ONLY dry fire shot
		if not dry_fired:
			dry_fired = true
			# Override play rate for dry fire (always use semi-auto speed)
			await player.player_animator.play_animation_and_await(anim_name, weapon.semi_fire_rate)
			# After dry firing once, automatically stop trying to fire
			if is_local_player:
				# Check for trigger release during the animation
				if not Input.is_action_pressed("left_click"):
					player.player_actions.queue_stop_firing_action(shots_fired)
					dry_fired = false
			# Remote players
			else:
				is_auto_firing = false
				dry_fired = false
		
		# Return here to prevent shooting a live round after the dry fire
		return
	
	# Play normal firing logic
	await player.player_animator.play_animation_and_await(anim_name, play_rate)
	# Increase our local firing counter to keep track of how many bullets we have fired
	shots_fired += 1
	
	if is_local_player:
		# If we are still holding the left click, continue firing
		if Input.is_action_pressed("left_click"):
			next_automatic_fire()
		# Check for trigger release during the animation
		else:
			player.player_actions.queue_stop_firing_action(shots_fired)
			dry_fired = false
	
	# For remote players
	else:
		# If we are lagging behind the server and we are trying to catch up
		if is_trying_to_syncronize:
			# If we still haven't reached the amount of shots we fired according to the server
			if shots_fired < server_shots_fired:
				# Check if we can actually fire (have ammo)
				if player.player_equipment.can_fire_weapon():
					# Continue firing to catch up
					next_automatic_fire()
					return
				
				# Out of ammo, stop trying to sync
				else:
					is_trying_to_syncronize = false
					is_auto_firing = false
					return
			else:
				# We've caught up, stop firing
				# NOTE this unblocks the player_actions for this remote player
				is_trying_to_syncronize = false
				is_auto_firing = false
				return
		
		# For remote players, always continue firing until we receive a stop packet
		if is_auto_firing:
			next_automatic_fire()


# Helper function to skip input if one of these is valid
func ignore_input() -> bool:
	if player.is_busy:
		return true
	if player.player_movement.autopilot_active:
		return true
	if player.is_mouse_over_ui:
		return true
	
	return false
