extends Node
class_name PlayerActions

# Preloading scripts
const Packets: GDScript = preload("res://packets.gd")

var player: Player = null # Our parent node

class QueuedAction:
	var action_type: String
	var action_data: Variant
	
	func _init(type: String, data: Variant = null):
		action_type = type
		action_data = data


# Private variables
var _queue: Array[QueuedAction] = []
var _is_processing: bool = false
var _current_action: QueuedAction = null
# target_id -> {damage: int, position: Vector3, timer: Timer}
var _damage_aggregation: Dictionary = {}
var _damage_aggregation_timeout: float = 0.3 # 300ms to aggregate damage


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	# Wait a single frame to allow time for the other player components to load
	await get_tree().process_frame
	player = get_parent()


func add_action(action_type: String, action_data: Variant = null) -> QueuedAction:
	var action = QueuedAction.new(action_type, action_data)
	
	_queue.append(action)
	
	if not _is_processing:
		process_next_action()
	
	return action


func complete_action() -> void:
	if not _current_action:
		return
	
	_current_action = null
	
	if not _queue.is_empty():
		process_next_action()
	else:
		_is_processing = false


func process_next_action() -> void:
	if _queue.is_empty():
		_is_processing = false
		return
	
	_is_processing = true
	_current_action = _queue.pop_front() # Get the next action
	
	# Process based on action type
	match _current_action.action_type:
		"move":
			_process_move_character_action(_current_action.action_data)
		"raise_weapon":
			_process_raise_weapon_action()
		"lower_weapon":
			_process_lower_weapon_action()
		"single_fire":
			_process_single_fire_action(_current_action.action_data)
		"multiple_fire":
			_process_multiple_fire_action(_current_action.action_data)
		"reload_weapon":
			_process_reload_weapon_action(_current_action.action_data)
		"toggle_fire_mode":
			_process_toggle_fire_mode_action()
		"switch_weapon":
			_process_switch_weapon_action(_current_action.action_data)
		"rotate":
			_process_rotate_action(_current_action.action_data)
		"apply_damage":
			_process_apply_damage_action(_current_action.action_data)
		"respawn":
			_process_respawn_action(_current_action.action_data)
		"death":
			_process_player_died_action(_current_action.action_data)
		"enter_crouch":
			_process_enter_crouch_action()
		"leave_crouch":
			_process_leave_crouch_action()
		_:
			push_error("Unknown action type: ", _current_action.action_type)
			complete_action()

#################
# QUEUE ACTIONS #
#################

func queue_move_action(destination: Vector2i) -> void:
	add_action("move", destination)

func queue_raise_weapon_action() -> void:
	add_action("raise_weapon")

func queue_lower_weapon_action() -> void:
	add_action("lower_weapon")

func queue_single_fire_action(target: Vector3) -> void:
	add_action("single_fire", target)

func queue_multiple_fire_action(hit_positions: Array[Vector3]) -> void:
	add_action("multiple_fire", hit_positions)

func queue_reload_weapon_action(slot: int) -> void:
	add_action("reload_weapon", {"slot": slot})

func queue_toggle_fire_mode_action() -> void:
	add_action("toggle_fire_mode")

func queue_switch_weapon_action(slot: int) -> void:
	add_action("switch_weapon", slot)

func queue_rotate_action(packet: Packets.RotateCharacter) -> void:
	add_action("rotate", packet)

func queue_enter_crouch_action() -> void:
	add_action("enter_crouch")

func queue_leave_crouch_action() -> void:
	add_action("leave_crouch")

###################
# PROCESS ACTIONS #
###################

# If our player is not busy,
# not in autopilot mode,
# not in any weapon aim state (can't move while aiming),
# and the cell is both reachable and available
func _validate_move_character(destination: Vector2i) -> bool:
	# If we are in autopilot mode
	if player.player_movement.autopilot_active:
		return false
	# If we are weapon aiming
	if player.is_in_weapon_aim_state():
		return false
	# If the cell is not reachable
	if not RegionManager.is_cell_reachable(destination):
		return false
	# If the cell is occupied by someone other than our player
	if not RegionManager.is_cell_available(destination):
		if RegionManager.get_object(destination) != player:
			return false
	
	# If we got this far, then we can move!
	return true


func _process_move_character_action(new_destination: Vector2i) -> void:
	# Only validate local player
	if player.is_local_player:
		# If the movement action is not valid
		if not _validate_move_character(new_destination):
			complete_action()
			return
		
		# If we are idling, we start local movement
		if not player.player_movement.in_motion:
			player.player_movement.start_movement_towards(
				player.player_movement.immediate_grid_destination,
				new_destination
			)
		
		player.player_packets.send_destination_packet(player.player_movement.immediate_grid_destination)
		
		complete_action()
	
	# Handle remote player movement
	else:
		# Get all consecutive movements
		var all_movements: Array[Vector2i] = _get_consecutive_movements(new_destination)
		# Get the last destination from all movements
		var final_destination: Vector2i = all_movements[-1]
		
		# Remove all but the first movement from queue (current one is being processed)
		for i in range(1, all_movements.size()):
			_remove_next_movement_action()
		
		# Get the current state
		var current_state: BaseState = player.player_state_machine.get_current_state()
		if not current_state:
			complete_action()
			return
		
		# If we are in a weapon aim state, we need to lower the weapon first
		if current_state.is_weapon_aim_idle_state():
			add_action("lower_weapon") # Queue a lower weapon action first
			add_action("move", final_destination) # Requeue movement action
			complete_action()
			return
		
		# Immediate grid destination
		var current_position: Vector2i = player.player_movement.immediate_grid_destination
		
		# Calculate path from immediate destination to new destination
		var path: Array[Vector2i] = player.player_movement.predict_path(
			current_position,
			final_destination
		)
		
		# Check if path is valid (needs at least 2 points: start and destination)
		if path.size() < 2:
			complete_action()
			return
		
		# Remove player from current immediate_grid_destination in grid BEFORE moving
		RegionManager.remove_object(current_position)
		
		# Set up movement for the remote player
		player.player_movement.handle_remote_player_movement(path)
		
		# NOTE Wait until the movement is complete before marking action as completed
		while player.player_movement.in_motion:
			await get_tree().process_frame
		
		complete_action()


# Collect consecutive movement actions from queue
func _get_consecutive_movements(first_destination: Vector2i) -> Array[Vector2i]:
	var destinations: Array[Vector2i] = [first_destination]
	
	# Look for consecutive movement actions without removing them
	for i in range(_queue.size()):
		if _queue[i].action_type == "move":
			var next_dest: Vector2i = _queue[i].action_data
			# Only add if it's different from the last one
			if next_dest != destinations[-1]:
				destinations.append(next_dest)
		else:
			break
	
	return destinations


func _remove_next_movement_action() -> void:
	for i in range(_queue.size()):
		if _queue[i].action_type == "move":
			_queue.remove_at(i)
			return


func _process_raise_weapon_action() -> void:
	# Only validate local player
	if player.is_local_player:
		# Check if we can raise weapon
		if not player.can_raise_weapon():
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_raise_weapon_packet()
	
	# Both local and remote players
	await _local_raise_weapon_and_await()
	complete_action()


# Perform local actions to raise weapon
func _local_raise_weapon_and_await() -> void:
	# Get the current state
	var current_state: BaseState = player.player_state_machine.get_current_state()
	if not current_state:
		return
		
	# Check if our weapon is already raised, if so, ignore
	if current_state.is_weapon_aim_idle_state():
		return
	
	# Perform local actions
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	
	# Determine animation and next state based on current state
	var animation_type: String
	var target_state_name: String
	
	match current_state_name:
		"rifle_down_idle", "shotgun_down_idle":
			animation_type = "down_to_aim"
			target_state_name = weapon_type + "_aim_idle"
		"rifle_crouch_down_idle", "shotgun_crouch_down_idle":
			animation_type = "crouch_down_to_crouch_aim"
			target_state_name = weapon_type + "_crouch_aim_idle"
		_:
			push_error("Error in match current_state inside _local_raise_weapon_and_await(), current_state_name: ", current_state_name, ", weapon_type: ", weapon_type)
			return
	
	await player.player_animator.play_weapon_animation_and_await(
		animation_type,
		weapon_type
	)
	
	# If we are not already in the same state
	if target_state_name != player.player_state_machine.get_current_state_name():
		player.player_state_machine.change_state(target_state_name)


func _process_lower_weapon_action() -> void:
	# Only validate local player
	if player.is_local_player:
		# Check if we can lower weapon
		if not player.can_lower_weapon():
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_lower_weapon_packet()
	
	# Both local and remote players
	await _local_lower_weapon_and_await()
	complete_action()


func _local_lower_weapon_and_await() -> void:
	# Get the current state
	var current_state: BaseState = player.player_state_machine.get_current_state()
	if not current_state:
		return
		
	# Check if our weapon is already down, if so, ignore
	if current_state.is_weapon_down_idle_state():
		return
	
	# Perform local actions
	player.is_aim_rotating = false # Disable aim rotation
	
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	
	# Determine animation and next state based on current state
	var animation_type: String
	var target_state_name: String
	
	match current_state_name:
		"rifle_aim_idle", "shotgun_aim_idle":
			animation_type = "aim_to_down"
			target_state_name = weapon_type + "_down_idle"
		"rifle_crouch_aim_idle", "shotgun_crouch_aim_idle":
			animation_type = "crouch_aim_to_crouch_down"
			target_state_name = weapon_type + "_crouch_down_idle"
		_:
			push_error("Error in match current_state inside _local_lower_weapon_and_await(), current_state_name: ", current_state_name, ", weapon_type: ", weapon_type)
			return
	
	await player.player_animator.play_weapon_animation_and_await(
		animation_type,
		weapon_type
	)
	
	# If our target state name is not empty
	if target_state_name != "":
		# If we are not already in the same state
		if target_state_name != player.player_state_machine.get_current_state_name():
			player.player_state_machine.change_state(target_state_name)


func _process_reload_weapon_action(data: Dictionary) -> void:
	# Only validate if local player can reload
	if player.is_local_player:
		if not player.can_reload_weapon():
			complete_action()
			return
	
		# If the current weapon doesn't match the weapon in the data, abort
		var weapon_slot: int = data["slot"]
		if weapon_slot != player.player_equipment.get_current_weapon_slot():
			complete_action()
			return
		
		# Get the current state
		var current_state: BaseState = player.player_state_machine.get_current_state()
		if not current_state:
			return
		
		# If we are in one of the weapon down states,
		# we need to queue a raise weapon action before we process this action
		if current_state.is_weapon_down_idle_state():
			queue_raise_weapon_action()
			queue_reload_weapon_action(weapon_slot)
			complete_action()
			return
		
		# If we don't have all of the data, meaning the packet is incomplete (because its local),
		# and this is the local player, then we send a packet to the server to request to reload
		if not data.has("magazine_ammo") and not data.has("reserve_ammo"):
			# After local validation, we send the packet
			player.player_packets.send_reload_weapon_packet(weapon_slot)
			
			# And now we just play the local reload animation,
			# Once the packet returns from the server, we update the ammo numbers
			await _local_reload_weapon_and_await()
			
			# If we are still holding right click after reloading
			if Input.is_action_pressed("right_click"):
				# Enable aim rotation
				player.is_aim_rotating = true
			# If we released the right click
			else:
				# Queue lowering the rifle
				queue_lower_weapon_action()
			
			complete_action()
			return
	
	# For remote players
	else:
		await _local_raise_weapon_and_await()
		await _local_reload_weapon_and_await()
	
	# Both local and remote players
	# If we got the ammo values from the server, then update the stats
	if data.has("magazine_ammo") and data.has("reserve_ammo"):
		var magazine_ammo: int = data["magazine_ammo"]
		var reserve_ammo: int = data["reserve_ammo"]
		# Update local state
		player.player_equipment.reload_equipped_weapon(magazine_ammo, reserve_ammo)
		complete_action()


# Perform local actions to reload
func _local_reload_weapon_and_await() -> void:
	# Get weapon data
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	# Disable aim rotation
	player.is_aim_rotating = false
	
	# Determine reload animation based on state and magazine ammo
	var reload_animation: String
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	
	# Check if magazine is empty (0 ammo) to decide between slow/fast reload
	var is_magazine_empty: bool = (player.player_equipment.get_current_ammo() == 0)
	
	match current_state_name:
		# Choose between slow or fast reload based on magazine ammo
		"rifle_aim_idle":
			if is_magazine_empty:
				reload_animation = "reload_slow"
			else:
				reload_animation = "reload_fast"
		"rifle_crouch_aim_idle":
			if is_magazine_empty:
				reload_animation = "crouch_reload_slow"
			else:
				reload_animation = "crouch_reload_fast"
		
		# Shotgun has a different reload system
		"shotgun_aim_idle", "shotgun_crouch_aim_idle":
			var is_crouching: bool = "crouch" in current_state_name
			
			# Calculate how many shells to load
			var current_ammo: int = player.player_equipment.get_current_ammo()
			var max_ammo: int
			if current_ammo == 0:
				max_ammo = 6
			else:
				max_ammo = player.player_equipment.get_current_weapon_max_ammo()
			var reserve_ammo: int = player.player_equipment.get_current_reserve_ammo()
			var shells_to_load: int = min(max_ammo - current_ammo, reserve_ammo)
			
			if shells_to_load <= 0:
				# No shells to load, just exit
				return
			
			# Prepare the animation names
			var reload_start_anim: String = "reload_start"
			var reload_shell_anim: String = "reload_shell"
			var reload_end_anim: String = "reload_end"
			
			if is_crouching:
				reload_start_anim = "crouch_reload_start"
				reload_shell_anim = "crouch_reload_shell"
				reload_end_anim = "crouch_reload_end"
			
			# Start reloading
			await player.player_animator.play_weapon_animation_and_await(reload_start_anim, weapon_type)
			# Loop over the load shell anim
			for i in range(shells_to_load):
				await player.player_animator.play_weapon_animation_and_await(reload_shell_anim, weapon_type)
				# Update local ammo as we load each shell (for visual feedback)
				player.player_equipment.set_current_ammo(current_ammo + i + 1)
				player.player_equipment.set_current_reserve_ammo(reserve_ammo - i - 1)
				player.player_equipment.update_hud_ammo()
			
			# Play the reload end animation
			await player.player_animator.play_weapon_animation_and_await(reload_end_anim, weapon_type)
			
			# Enable aim rotation after reload
			player.is_aim_rotating = true
			# Play the appropriate idle animation after
			player.player_animator.switch_animation("idle")
			
			return # We break early
		
		# Error handling
		"_":
			push_error("Error inside _process_reload_weapon_action for animation: ", reload_animation, ", weapon_type: ", weapon_type, ", current_state: ", current_state_name)
			return
	
	await player.player_animator.play_weapon_animation_and_await(
		reload_animation,
		weapon_type
	)
	
	# Enable aim rotation after reload
	player.is_aim_rotating = true
	# Play the appropriate idle animation after
	player.player_animator.switch_animation("idle")


# Perform local actions for single fire or multiple fire weapon
func _local_fire_weapon_and_await() -> void:
	# Get weapon data
	var weapon = player.player_equipment.equipped_weapon
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	var is_crouching = "crouch" in player.player_state_machine.get_current_state_name()
	var has_ammo: bool = player.player_equipment.can_fire_weapon()
	var firing_action: String = "fire_single"
	var pump_action: String = "pump"
	# Assume standing first, override if crouching
	var play_rate: float = weapon.get_animation_play_rate("standing")
	if is_crouching:
		play_rate = weapon.get_animation_play_rate("crouching")
	
	# Adjust for dry fire
	if not has_ammo:
		play_rate = weapon.semi_fire_rate
		player.dry_fired = true
	
	# For shotguns, handle fire + pump sequence
	if weapon_type == "shotgun":
		if is_crouching:
			firing_action = "crouch_fire_single"
			pump_action = "crouch_pump"
	
		# Ammo decrement happens from player_equipment.weapon_fire()
		await player.player_animator.play_weapon_animation_and_await(firing_action, weapon_type, play_rate)
		
		# If we had ammo (not dry fire), play the pump animation
		if has_ammo:
			await player.player_animator.play_weapon_animation_and_await(pump_action, weapon_type, play_rate)
	
	# For all other weapons
	else:
		if is_crouching:
			firing_action = "crouch_fire_single"
			pump_action = "crouch_pump"
		
		# Check if we have ammo, adjust for dry fire
		if not has_ammo:
			play_rate = weapon.semi_fire_rate
			player.dry_fired = true

		# Ammo decrement happens from player_equipment.weapon_fire()
		await player.player_animator.play_weapon_animation_and_await(firing_action, weapon_type, play_rate)
	
	# After firing, we switch back to idle
	# Switch to the appropiate idle state based on our current locomotion
	var target_state_name: String = player.player_animator.get_aim_state_name()
	# If we are not already in the same state (switching from one rifle to another rifle for example)
	if target_state_name != player.player_state_machine.get_current_state_name():
		player.player_state_machine.change_state(target_state_name)
	
	# Play the appropriate idle animation after
	player.player_animator.switch_animation("idle")


func _process_single_fire_action(target: Vector3) -> void:
	# Only validate local player
	if player.is_local_player:
		# If target is invalid
		if target == Vector3.ZERO:
			complete_action()
			return
		
		# Check if we can fire regardless of ammo count
		if not player.can_fire_weapon():
			complete_action()
			return
		
		# If the muzzle is inside geometry (walls), don't fire
		if player.player_equipment.equipped_weapon.is_weapon_inside_wall():
			complete_action()
			return
		
		# Only calculate projectiles if we have ammo
		var hit_positions: Array[Vector3] = []
		# Check if we have ammo
		if player.player_equipment.can_fire_weapon():
			# Calculate recoil first and get the actual hit position
			hit_positions = player.player_equipment.calculate_weapon_hit_positions(target)
			
			# Store the hit positions in our player equipment
			player.player_equipment.set_next_hit_positions(hit_positions)
			
			# Process hits for damage reporting
			var hits_by_target = player.player_equipment.process_hits_for_damage()
		
			# For rifles/pistols, send single hit position
			if hit_positions.size() > 0:
				player.player_packets.send_fire_weapon_packet(hit_positions[0])
				
				# Send damage report if we hit a target
				for target_id in hits_by_target:
					var hits = hits_by_target[target_id]
					if hits.size() > 0:
						var hit = hits[0]
						player.player_packets.send_report_player_damage_packet(target_id, hit.position, hit.is_critical)
		
		# Send the packet only for the dry fire effect
		else:
			player.player_packets.send_fire_weapon_packet()
	
	# Remote players
	else:
		# Store the hit position that came from the server (with recoil already applied)
		player.player_equipment.set_next_hit_positions([target])
		# Check if we have ammo
		if player.player_equipment.can_fire_weapon():
			# Process the hits for damage so we spawn SFX and sounds
			player.player_equipment.process_hits_for_damage()
	
	# Perform local actions for both local and remote players
	_local_fire_weapon_and_await()
	complete_action()


func _process_multiple_fire_action(hit_positions: Array[Vector3]) -> void:
# Only validate local player
	if player.is_local_player:
		# If hit_positions is empty
		if hit_positions.size() == 0:
			complete_action()
			return
		
		# Check if we can fire regardless of ammo count
		if not player.can_fire_weapon():
			complete_action()
			return
		
		# If the muzzle is inside geometry (walls), don't fire
		if player.player_equipment.equipped_weapon.is_weapon_inside_wall():
			complete_action()
			return
		
		# Only calculate projectiles if we have ammo
		var local_hit_positions: Array[Vector3] = []
		# Check if we have ammo
		if player.player_equipment.can_fire_weapon():
			# Calculate recoil first and get the actual hit position using our target
			local_hit_positions = player.player_equipment.calculate_weapon_hit_positions(hit_positions[0])
			
			# Store the hit positions in our player equipment
			player.player_equipment.set_next_hit_positions(local_hit_positions)
			
			# Process hits for damage reporting
			var hits_by_target = player.player_equipment.process_hits_for_damage()
			
			# For shotguns, send all hit positions
			player.player_packets.send_fire_weapon_multiple_packet(local_hit_positions)
			
			# Send damage reports for each target
			for target_id in hits_by_target:
				var hits = hits_by_target[target_id]
				player.player_packets.send_report_player_damage_multiple_packet(target_id, hits)
		
		# Send the packet only for the dry fire effect
		else:
			player.player_packets.send_fire_weapon_packet()
	
	# Remote players
	else:
		# Store the hit positions that came from the server
		player.player_equipment.set_next_hit_positions(hit_positions)
		# Check if we have ammo
		if player.player_equipment.can_fire_weapon():
			# Process the hits for damage so we spawn SFX and sounds
			player.player_equipment.process_hits_for_damage()
	
	# Perform local actions for both local and remote players
	_local_fire_weapon_and_await()
	complete_action()


func _process_toggle_fire_mode_action() -> void:
	# Only validate local player
	if player.is_local_player:
		# Check if we can toggle fire mode
		if not player.can_toggle_fire_mode():
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_toggle_fire_mode_packet()
	
	# Perform local actions
	player.player_audio.play_weapon_fire_mode_selector()
	player.player_equipment.toggle_fire_mode()
	
	complete_action()


func _process_switch_weapon_action(slot: int) -> void:
	# Only validate local player
	if player.is_local_player:
		# Check if we can switch weapons
		if not player.can_switch_weapon(slot):
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_switch_weapon_packet(slot)
	
	# Perform local actions
	# Get current weapon type for animation
	var current_weapon_type: String = player.player_equipment.get_current_weapon_type()
	
	# If we have a weapon equipped, play unequip animation
	if current_weapon_type != "unarmed":
		await player.player_animator.play_weapon_animation_and_await(
			"unequip",
			current_weapon_type
		)
	
	# Switch weapons
	player.player_equipment.switch_weapon_by_slot(slot)
	
	# Get new weapon type
	current_weapon_type = player.player_equipment.get_current_weapon_type()
	
	# If we are switching to a weapon, play equip animation
	if current_weapon_type != "unarmed":
		await player.player_animator.play_weapon_animation_and_await(
			"equip",
			current_weapon_type
		)
	
	# Update HUD
	if current_weapon_type != "unarmed":
		player.player_equipment.show_weapon_hud()
	else:
		player.player_equipment.hide_weapon_hud()
	
	# Switch to the appropiate state based on weapon type
	var target_state_name: String = player.player_equipment.get_weapon_state_by_weapon_type(current_weapon_type)
	# If we are not already in the same state (switching from one rifle to another rifle for example)
	if target_state_name != player.player_state_machine.get_current_state_name():
		player.player_state_machine.change_state(target_state_name)
	
	complete_action()


# Helper function to ensure the weapon is raised before firing
func _ensure_weapon_raised() -> void:
	# If we're already in a weapon aim state, we're good
	if player.is_in_weapon_aim_state():
		return
	
	# Get the current state
	var current_state: BaseState = player.player_state_machine.get_current_state()
	if not current_state:
		return
	
	# If we're in a weapon down state, raise the weapon
	if current_state.is_weapon_down_idle_state():
		# Play the raised weapon animation directly without using the action queue
		var weapon_type: String = player.player_equipment.get_current_weapon_type()
		await player.player_animator.play_weapon_animation_and_await(
			"down_to_aim",
			weapon_type
		)
		
		# Switch to the appropiate state
		var target_state_name: String = weapon_type + "_aim_idle"
		if target_state_name != player.player_state_machine.get_current_state_name():
			player.player_state_machine.change_state(target_state_name)


func _process_rotate_action(packet: Packets.RotateCharacter) -> void:
	var rotation_y: float = packet.get_rotation_y()
	var await_rotation: bool = packet.get_await_rotation()
	
	# Set the rotation target
	player.player_movement.rotation_target = rotation_y
	player.player_movement.is_rotating = true
	
	if await_rotation:
		# Wait for the rotation to complete
		var rotation_threshold = 0.1 # Radians (about 6 degrees)
		while abs(player.model.rotation.y - rotation_y) > rotation_threshold:
			await get_tree().process_frame
	
	# NOTE We don't send packets from this action since we are sending them from base_state.gd
	
	complete_action()


func _process_apply_damage_action(data: Dictionary) -> void:
	# var attacker_id: int = data["attacker_id"]
	var target_id: int = data["target_id"]
	var damage: int = data["damage"]
	# var damage_type: String = data["damage_type"]
	# var is_critical: bool = data["is_critical"]
	
	# Only process if the target still exists and is alive
	if GameManager.is_player_valid(target_id):
		var target_player: Player = GameManager.get_player_by_id(target_id)
		if target_player:
			if target_player.is_alive():
				# Reduce health for local victim (with HUD update)
				target_player.decrease_health(damage, true)
				
				# Get the target's world position and spawn the damage there
				var damage_position: Vector3 = Vector3(target_player.position)
				damage_position.y += target_player.DAMAGE_ORIGIN
				
				# Regular damage, reduce health inside _aggregate_damage
				_aggregate_damage(target_id, damage, damage_position)
			else:
				clear_pending_damage_numbers(target_id)
	
	complete_action()


func _aggregate_damage(target_id: int, damage: int, damage_position: Vector3) -> void:
	if not GameManager.is_player_valid(target_id):
		return
	
	# If we already have a pending aggregation for this target
	if _damage_aggregation.has(target_id):
		var aggregate: Dictionary = _damage_aggregation[target_id]
		aggregate.damage += damage
		aggregate.position = damage_position # Use the last position
	else:
		# Create new aggregation
		var timer: Timer = Timer.new()
		timer.wait_time = _damage_aggregation_timeout
		timer.one_shot = true
		timer.timeout.connect(_on_damage_aggregation_timeout.bind(target_id))
		add_child(timer)
		timer.start(_damage_aggregation_timeout)
		
		_damage_aggregation[target_id] = {
			"damage": damage,
			"position": damage_position,
			"timer": timer
		}


# Handles damage aggregation timer timeout
func _on_damage_aggregation_timeout(target_id: int) -> void:
	if _damage_aggregation.has(target_id):
		var aggregate: Dictionary = _damage_aggregation[target_id]
		
		# Only process if the target still exists
		if GameManager.is_player_valid(target_id):
			SfxManager.spawn_damage_number(aggregate.damage, aggregate.position)
		
		# Clean up
		aggregate.timer.queue_free()
		_damage_aggregation.erase(target_id)


func _process_respawn_action(spawn_character_packet: Packets.SpawnCharacter) -> void:
	var target_id: int = spawn_character_packet.get_id()
	# Attempt to retrieve the player character object
	var target_player: Player = GameManager.get_player_by_id(target_id)
	if not target_player:
		complete_action()
		return
	
	# Clear any pending damage aggregation and any pending damage actions for the respawned player
	clear_pending_damage_numbers(target_id)
	_clear_pending_damage_actions(target_id)
	
	var new_position: Vector2i = Vector2i(spawn_character_packet.get_position().get_x(), spawn_character_packet.get_position().get_z())
	
	# Add player to the new position in the grid
	RegionManager.set_object(new_position, target_player)
	
	# Update stats
	target_player.health = spawn_character_packet.get_health()
	target_player.max_health = spawn_character_packet.get_max_health()
	
	# Update all movement related positions
	target_player.player_movement.server_grid_position = new_position
	target_player.player_movement.grid_position = new_position
	target_player.player_movement.grid_destination = new_position
	target_player.player_movement.immediate_grid_destination = new_position
	target_player.player_movement.interpolated_position = Utils.map_to_local(new_position)
	
	# Reset position and rotation
	target_player.spawn_rotation = spawn_character_packet.get_rotation_y()
	target_player.player_movement.setup_movement_data_at_spawn()
	target_player.model.rotation.y = target_player.spawn_rotation # Snap the rotation to the new spawn rotation
	
	# Update weapon slots from the packet (just like initial spawn)
	var weapon_slots: Array[Dictionary] = []
	var spawn_weapons = spawn_character_packet.get_weapons()
	
	# Initialize with empty slots
	for i in range(target_player.player_equipment.MAX_WEAPON_SLOTS):
		weapon_slots.append({
			"weapon_name": "unarmed",
			"weapon_type": "unarmed",
			"display_name": "Empty",
			"ammo": 0,
			"reserve_ammo": 0,
			"fire_mode": 0
		})
	
	# Extract weapon slots from the packet
	for i in range(spawn_weapons.size()):
		var weapon_slot = spawn_weapons[i]
		var slot_index = weapon_slot.get_slot_index()
		if slot_index < target_player.player_equipment.MAX_WEAPON_SLOTS:
			weapon_slots[slot_index] = {
				"weapon_name": weapon_slot.get_weapon_name(),
				"weapon_type": weapon_slot.get_weapon_type(),
				"display_name": weapon_slot.get_display_name(),
				"ammo": weapon_slot.get_ammo(),
				"reserve_ammo": weapon_slot.get_reserve_ammo(),
				"fire_mode": weapon_slot.get_fire_mode()
			}
	
	# Update the player's weapon slots
	target_player.player_equipment.weapon_slots = weapon_slots
	target_player.player_equipment.current_slot = spawn_character_packet.get_current_weapon()
	
	# Update the equipped weapon
	target_player.player_equipment.update_equipped_weapon()
	
	# Call the player's respawn handler
	target_player.handle_respawn()
	
	# Reset any death state and go to appropriate idle state
	target_player.update_weapon_state()
	
	complete_action()


func _process_player_died_action(player_died_packet: Packets.PlayerDied) -> void:
	# var attacker_id: int = player_died_packet.get_attacker_id()
	var target_id: int = player_died_packet.get_target_id()
	
	# Only process if the target still exists
	if not GameManager.is_player_valid(target_id):
		complete_action()
		return
	
	var target_player: Player = GameManager.get_player_by_id(target_id)
	target_player.handle_death()
	
	complete_action()


# Clears damage aggregation for this player
func clear_pending_damage_numbers(target_id: int) -> void:
	if _damage_aggregation.has(target_id):
		var aggregate: Dictionary = _damage_aggregation[target_id]
		aggregate.timer.stop()
		aggregate.timer.queue_free()
		_damage_aggregation.erase(target_id)


# Removes any pending apply_damage from the queue
func _clear_pending_damage_actions(target_id: int) -> void:
	var i: int = 0
	while i < _queue.size():
		var action = _queue[i]
		if action.action_type == "apply_damage" and action.action_data["target_id"] == target_id:
			_queue.remove_at(i)
		else:
			i += 1


func _process_enter_crouch_action() -> void:
	if player.is_local_player:
		# Report to the server we are entering crouch state
		player.player_packets.send_crouch_character_packet(true)
	
	# Determine animation and next state based on current state and weapon type
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	var animation_type: String
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	var target_state_name: String = ""
	
	# Determine target crouch state based on current state
	match current_state_name:
		"unarmed_idle":
			animation_type = "down_to_crouch_down"
			target_state_name = "unarmed_crouch_idle"
		# WEAPON DOWN TO WEAPON CROUCH DOWN
		"rifle_down_idle", "shotgun_down_idle":
			animation_type = "down_to_crouch_down"
			target_state_name = weapon_type + "_crouch_down_idle"
		# WEAPON AIM TO WEAPON CROUCH AIM
		"rifle_aim_idle", "shotgun_aim_idle":
			animation_type = "aim_to_crouch_aim"
			target_state_name = weapon_type + "_crouch_aim_idle"
		"_":
			push_error("Error in match current_state_name inside _process_enter_crouch_action()")
			return
	
	if animation_type != "":
		await player.player_animator.play_weapon_animation_and_await(
			animation_type,
			weapon_type
		)
	
	if target_state_name != "":
		# If we are not already in the same state
		if target_state_name != player.player_state_machine.get_current_state_name():
			player.player_state_machine.change_state(target_state_name)
	
	# Adjust the collision shapes AFTER changing states
	player.update_collision_shapes()
	
	complete_action()


func _process_leave_crouch_action() -> void:
	if player.is_local_player:
		# Report to the server we are leaving crouch state
		player.player_packets.send_crouch_character_packet(false)
	
	# Determine animation and next state based on current state and weapon type
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	var animation_type: String
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	var target_state_name: String = ""
	
	# Determine target crouch state based on current state
	match current_state_name:
		"unarmed_crouch_idle":
			animation_type = "crouch_down_to_down"
			target_state_name = "unarmed_idle"
		# WEAPON CROUCH DOWN TO WEAPON DOWN
		"rifle_crouch_down_idle", "shotgun_crouch_down_idle":
			animation_type = "crouch_down_to_down"
			target_state_name = weapon_type + "_down_idle"
		# WEAPON CROUCH AIM TO WEAPON AIM
		"rifle_crouch_aim_idle", "shotgun_crouch_aim_idle":
			animation_type = "crouch_aim_to_aim"
			target_state_name = weapon_type + "_aim_idle"
		"_":
			push_error("Error in match current_state_name inside _process_leave_crouch_action()")
			return
	
	if animation_type != "":
		await player.player_animator.play_weapon_animation_and_await(
			animation_type,
			weapon_type
		)
	
	# If target_state_name is valid
	if target_state_name != "":
		# If we are not already in the same state
		if target_state_name != player.player_state_machine.get_current_state_name():
			player.player_state_machine.change_state(target_state_name)
	
	# Adjust the collision shapes AFTER changing states
	player.update_collision_shapes()
	
	# After leaving crouch
	# If this is my local player
	if player.is_local_player:
		# Check if we have an interact target first
		if player.pending_interaction != null:
			player.handle_pending_interaction()
		# Check if we have a destination set
		elif player.player_movement.grid_destination != player.player_movement.grid_position:
			# Queue movement to the stored destination
			queue_move_action(player.player_movement.grid_destination)
	
	complete_action()
