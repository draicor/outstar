extends Node
class_name BaseState

signal finished(next_state_name)

var player_state_machine: PlayerStateMachine = null
var player: Player = null
var state_name: String = "unnamed_state"
var is_local_player: bool = false # set to true for local player
var signals_connected: bool = false # to only do this once
# Rotation broadcast logic
# 0.5 seconds for idle aim and 0.25 seconds for automatic firing
const AIM_ROTATION_INTERVAL: float = 0.5
const FIRING_ROTATION_INTERVAL: float = 0.25
var rotation_sync_timer: float = 0.0
var last_sent_rotation: float = 0.0
var rotation_timer_interval: float = AIM_ROTATION_INTERVAL
const ROTATION_CHANGE_THRESHOLD: float = 0.05 # radians
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


# Called from different idle states to switch to another weapon
func switch_weapon(slot: int, broadcast: bool = false) -> void:
	var equipment = player.player_equipment
	var animator = player.player_animator
	var packets = player.player_packets
	
	# If the new slot is not valid or the weapon is already equipped, skip
	if equipment.is_invalid_weapon_slot(slot) or equipment.current_slot == slot:
		packets.complete_packet()
		return
	
	# Block input
	player.is_busy = true
	
	# If we set it to broadcast and this is our local player
	if broadcast and is_local_player:
		# Report to the server we'll switch weapons
		packets.send_switch_weapon_packet(slot)
	
	# Unequip
	if equipment.equipped_weapon:
		# Play the unequip animation if valid
		var current_type: String = equipment.get_current_weapon_type()
		if animator.get_weapon_animation("unequip", current_type) != {}:
			equipment.hide_weapon_hud()
			await animator.play_weapon_animation_and_await("unequip", current_type)
			player.is_busy = true # Block input again because animator released it
	
	equipment.switch_weapon_by_slot(slot) # <-- Calls unequip and equip weapon
	
	# Check if slot has a valid weapon
	var weapon_type: String = equipment.weapon_slots[slot]["weapon_type"]
	var weapon_state: String = equipment.get_weapon_state_by_weapon_type(weapon_type)
	if weapon_state != "":
		# Switch to the correct weapon state based on weapon type
		if animator.get_weapon_animation("equip", weapon_type) != {}:
			await animator.play_weapon_animation_and_await("equip", weapon_type)
			player.is_busy = true # Block input again because animator released it
			equipment.update_hud_ammo()
		
		# If we are not already in the same state, try to change to it
		if player.player_state_machine.get_current_state_name() != weapon_state:
			player.player_state_machine.change_state(weapon_state)
	
	# Release input
	player.is_busy = false
	
	if not is_local_player:
		player.player_packets.complete_packet()


# Returns true if this character has its weapon down
func is_weapon_down_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_down_idle":
			return true
		_:
			return false


# Called from different weapon states to reload
func reload_weapon_and_await(slot: int, amount: int, broadcast: bool) -> void:
	var equipment = player.player_equipment
	var animator = player.player_animator
	var packets = player.player_packets
	
	# Check that we have the right weapon equipped
	if slot != equipment.current_slot:
		packets.complete_packet()
		return
	
	# Block input
	player.is_busy = true
	
	# Get current weapon type and reload animation
	var weapon_type: String = equipment.get_current_weapon_type()
	
	# Check if we are in the weapon_down_idle_state before reloading
	if is_weapon_down_idle_state():
		# If we set it to broadcast and this is our local player
		if broadcast and is_local_player:
			await raise_weapon_and_await(true)
		else:
			await raise_weapon_and_await(false)
	
	# Disable aim rotation while reloading
	if player_state_machine.get_current_state_name() == weapon_type + "_aim_idle":
		player_state_machine.get_current_state().is_aim_rotating = false
	
	# If we set it to broadcast and this is our local player
	if broadcast and is_local_player:
		# Report to the server we'll switch weapons
		packets.send_reload_weapon_packet(equipment.current_slot, amount)
	
	# Play the reload animation
	await animator.play_weapon_animation_and_await(
		"reload",
		weapon_type
	)
	player.is_busy = true # Block input again because animator released it
	
	# Update the ammo locally
	equipment.reload_equipped_weapon(amount)
	# Reset the dry fired variable because we added ammo
	dry_fired = false
	
	# Release input
	player.is_busy = false
	
	# Enable aim rotation after reload
	if player_state_machine.get_current_state_name() == weapon_type + "_aim_idle":
		player_state_machine.get_current_state().is_aim_rotating = true
	
	if not is_local_player:
		player.player_packets.complete_packet()


# Called to raise the current weapon
func raise_weapon_and_await(broadcast: bool) -> void:
	# Get current weapon type
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	
	# Block input
	player.is_busy = true
	
	# Play the raise weapon animation
	await player.player_animator.play_weapon_animation_and_await(
		"down_to_aim",
		weapon_type
	)
	player.is_busy = true # Block input again because animator released it
	
	# Transition to the aim state for this weapon
	player.player_state_machine.change_state(weapon_type + "_aim_idle")
	
	# Release input
	player.is_busy = false
	
	# If we set it to broadcast and this is our local player
	if broadcast and is_local_player:
		# Report to the server we are raising our weapon
		player.player_packets.send_raise_weapon_packet()
	
	if not is_local_player:
		player.player_packets.complete_packet()


# Called to lower the current weapon
func lower_weapon_and_await(broadcast: bool) -> void:
	# Get current weapon type
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	
	# Block input
	player.is_busy = true
	
	# Play the lower weapon animation
	await player.player_animator.play_weapon_animation_and_await(
		"aim_to_down",
		weapon_type
	)
	player.is_busy = true # Block input again because animator released it
	
	# Transition to the down state for this weapon
	player.player_state_machine.change_state(weapon_type + "_down_idle")
	
	# Release input
	player.is_busy = false
	
	# If we set it to broadcast and this is our local player
	if broadcast and is_local_player:
		# Report to the server we are lowering our weapon
		player.player_packets.send_lower_weapon_packet()
	
	if not is_local_player:
		player.player_packets.complete_packet()


# Handles single fire of firearms
func single_fire(target: Vector3, broadcast: bool) -> void:
	if target == Vector3.ZERO:
		return
	
	player.player_equipment.calculate_weapon_direction(target)
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
			if is_local_player:
				# If we set it to broadcast and this is our local player
				if broadcast:
				# Sync the rotation right before sending the fire weapon packet
					rotation_sync_timer = 0.0
					player.player_packets.send_fire_weapon_packet(target, player.player_movement.rotation_target)
				# If after the animation ends our trigger is not pressed
				if not Input.is_action_pressed("left_click"):
					dry_fired = false
			else: # remote player
				dry_fired = false
				player.player_packets.complete_packet()
				return
		# Abort here preventing shooting another round
		return
	
	# Play normal firing logic
	await player.player_animator.play_animation_and_await(anim_name, play_rate)
	
	if is_local_player:
		# If we set it to broadcast and this is our local player
		if broadcast:
			# Sync the rotation right before sending the fire weapon packet
			rotation_sync_timer = 0.0
			player.player_packets.send_fire_weapon_packet(target, player.player_movement.rotation_target)

		# If after the animation ends our trigger is not pressed
		if not Input.is_action_pressed("left_click"):
			dry_fired = false
	else: # remote player
		player.player_packets.complete_packet()


func toggle_fire_mode(broadcast: bool) -> void:
	player.player_audio.play_weapon_fire_mode_selector()
	player.player_equipment.toggle_fire_mode()
	
	# If we set it to broadcast and this is our local player
	if is_local_player and broadcast:
		player.player_packets.send_toggle_fire_mode_packet()
	
	# If remote player
	if not is_local_player:
		player.player_packets.complete_packet()


func start_automatic_firing(broadcast: bool) -> void:
	if is_local_player and broadcast:
		# Send our current rotation and also our remaining ammo on the currently equipped weapon
		player.player_packets.send_start_firing_weapon_packet(player.player_movement.rotation_target, player.player_equipment.get_current_ammo())
		# Reduce the rotation timer interval by half because we want accurate aiming
		rotation_timer_interval = FIRING_ROTATION_INTERVAL
	
	is_auto_firing = true
	next_automatic_fire() # Fire immediately
	
	# If remote player
	if not is_local_player:
		player.player_packets.complete_packet()


func stop_automatic_firing(broadcast: bool) -> void:
	if is_local_player and broadcast:
		player.player_packets.send_stop_firing_weapon_packet(player.player_movement.rotation_target, shots_fired)
		shots_fired = 0 # Reset the local shots_fired variable after sending the packet
		# Increase the rotation update interval since we are no longer firing
		rotation_timer_interval = AIM_ROTATION_INTERVAL
		is_auto_firing = false
	
	# If remote player
	if not is_local_player:
		# If we predicted the same amount of bullets the player fired, then stop firing
		if shots_fired == server_shots_fired:
			# Reset all variables and stop firing
			is_auto_firing = false
			is_trying_to_syncronize = false
			shots_fired = 0
			server_shots_fired = 0
			player.player_packets.complete_packet()
		# If we fired more rounds than we were supposed to (predicting failed),
		# reimburse the ammo difference to this remote player in my own local session
		elif shots_fired > server_shots_fired:
			# Stop firing immediately
			is_auto_firing = false
			is_trying_to_syncronize = false
			var ammo_difference: int = shots_fired - server_shots_fired
			var ammo_to_reimburse: int = player.player_equipment.get_current_ammo() + ammo_difference
			# Reset all variables
			shots_fired = 0
			server_shots_fired = 0
			player.player_equipment.set_current_ammo(ammo_to_reimburse)
			player.player_packets.complete_packet()
		# If local shots fired is less than the shots the server says we need to take,
		# keep firing until we are in sync
		elif shots_fired < server_shots_fired:
			is_trying_to_syncronize = true
			next_automatic_fire()


# Tries to fire the next round (live or dry fire) in automatic fire mode,
# It also processes the next packet in the packet queue after firing, uses recursion
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
					stop_automatic_firing(true)
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
			stop_automatic_firing(true)
			dry_fired = false
	
	# For remote players
	else:
		# If we are lagging behind the server and we are trying to catch up
		if is_trying_to_syncronize:
			# If we still haven't reached the amount of shots we fired according to the server
			if shots_fired < server_shots_fired:
				# Try to keep processing the stop_firing_packet we previously got
				player.player_packets.try_process_current_packet()
				return
			else:
				is_trying_to_syncronize = false
				player.player_packets.try_process_current_packet()
				return
		
		# Try to process next packet after animation ends
		player.player_packets.try_process_next_packet()
		
		# If after processing the packet, we still want to keep shooting
		if is_auto_firing:
			next_automatic_fire()
		else:
			# NOTE I don't really know if this below is doing anything
			player.player_packets.complete_packet()
