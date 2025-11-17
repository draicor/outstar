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
	
	# DEBUG
	#if not player.is_local_player:
		#print(Time.get_ticks_msec(), " ", _current_action.action_type)
	
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
		"start_firing":
			_process_start_firing_action(_current_action.action_data)
		"stop_firing":
			_process_stop_firing_action(_current_action.action_data)
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

func queue_start_firing_action(ammo: int) -> void:
	add_action("start_firing", ammo)

func queue_stop_firing_action(server_shots_fired: int) -> void:
	add_action("stop_firing", server_shots_fired)

func queue_reload_weapon_action(amount: int) -> void:
	add_action("reload_weapon", {"amount": amount})

func queue_toggle_fire_mode_action() -> void:
	add_action("toggle_fire_mode")

func queue_switch_weapon_action(slot: int) -> void:
	add_action("switch_weapon", slot)

func queue_rotate_action(rotation_y: float) -> void:
	add_action("rotate", rotation_y)

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
		
		# If we are idling, we start movement locally
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
	
	# Perform local actions
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	await player.player_animator.play_weapon_animation_and_await(
		"down_to_aim",
		weapon_type
	)
	
	# Switch to the appropiate state based on weapon type
	var target_state_name: String = weapon_type + "_aim_idle"
	# If we are not already in the same state
	if target_state_name != player.player_state_machine.get_current_state_name():
		player.player_state_machine.change_state(target_state_name)
	
	complete_action()


func _process_lower_weapon_action() -> void:
	# Only validate local player
	if player.is_local_player:
		# Check if we can lower weapon
		if not player.can_lower_weapon():
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_lower_weapon_packet()
	
	# Perform local actions
	# Disable aim rotation
	player.is_aim_rotating = false
	
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	await player.player_animator.play_weapon_animation_and_await(
		"aim_to_down",
		weapon_type
	)
	
	# Switch to the appropiate state based on weapon type
	var target_state_name: String = weapon_type + "_down_idle"
	# If we are not already in the same state
	if target_state_name != player.player_state_machine.get_current_state_name():
		player.player_state_machine.change_state(target_state_name)
	
	complete_action()


func _process_reload_weapon_action(data: Dictionary) -> void:
	# Only validate local player
	if player.is_local_player:
		# Check if we can reload
		if not player.can_reload_weapon():
			complete_action()
			return
	
	var weapon_slot = player.player_equipment.current_slot
	var amount = data["amount"]
	
	if player.is_local_player:
		# After local validation, we send the packet
		player.player_packets.send_reload_weapon_packet(weapon_slot, amount)
	
	# Perform local actions
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	# Disable aim rotation
	player.is_aim_rotating = false
	
	await player.player_animator.play_weapon_animation_and_await(
		"reload",
		weapon_type
	)
	
	# Enable aim rotation after reload
	player.is_aim_rotating = true
	
	# Play the rifle aim idle animation
	player.player_animator.switch_animation("idle")
	# Update local state
	player.player_equipment.reload_equipped_weapon(amount)
	
	if player.is_local_player:
		# If we are still holding right click after reloading
		if Input.is_action_pressed("right_click"):
			# Enable aim rotation
			player.is_aim_rotating = true
		# If we released the right click
		else:
			# Queue lowering the rifle
			queue_lower_weapon_action()
	
	complete_action()


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
		
		# After local validation, we send the packet
		player.player_packets.send_fire_weapon_packet(target, player.player_movement.rotation_target)
	
	# Perform local actions
	# Get weapon data
	var weapon = player.player_equipment.equipped_weapon
	var anim_name: String = weapon.get_animation()
	var play_rate: float = weapon.get_animation_play_rate()
	
	# Check if we have ammo
	var has_ammo: bool = player.player_equipment.can_fire_weapon()
	
	# Adjust for dry fire
	if not has_ammo:
		play_rate = weapon.semi_fire_rate
		player.dry_fired = true

	# Ammo decrement happens from player_equipment.weapon_fire()
	await player.player_animator.play_animation_and_await(anim_name, play_rate)
	
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


func _process_start_firing_action(ammo: int) -> void:
	# Only validate local player
	if player.is_local_player:
		# Check if we can start firing
		if not player.can_start_firing():
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_start_firing_weapon_packet(
			player.player_movement.rotation_target,
			player.player_equipment.get_current_ammo()
		)
	
	# Get the current state
	var current_state: BaseState = player.player_state_machine.get_current_state()
	if not current_state:
		complete_action()
		return
	
	# If we are in a weapon down state, we need to raise the weapon first
	if current_state.is_weapon_down_idle_state():
		# Queue a raise weapon action first
		add_action("raise_weapon")
		# Requeue the start firing action
		add_action("start_firing", ammo)
		complete_action()
		return
	
	if not player.is_local_player:
		player.player_equipment.set_current_ammo(ammo)
	
	# Perform local actions
	player.shots_fired = 0
	player.is_auto_firing = true
	
	# For remote players, we need to track the expected shot count
	if not player.is_local_player:
		player.expected_shots_fired = -1 # Unknown until we get stop_firing
	
	# Start firing immediately
	current_state.next_automatic_fire()
	
	# Wait one frame to ensure the automatic firing loop has started
	await get_tree().process_frame
	
	complete_action()


func _process_stop_firing_action(server_shots_fired: int) -> void:
	# Get the current state
	var current_state: BaseState = player.player_state_machine.get_current_state()
	if not current_state:
		complete_action()
		return
	
	# Only validate local player
	if player.is_local_player:
		# Check if we are firing, if not, abort
		if not player.is_auto_firing:
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_stop_firing_weapon_packet(
			player.player_movement.rotation_target,
			player.shots_fired
		)
		
		player.is_auto_firing = false
		player.dry_fired = false
	
	# For remote players
	if not player.is_local_player:
		# Store the server's shot count
		player.expected_shots_fired = server_shots_fired
		
		# Stop any current firing loop
		player.is_auto_firing = false
		
		# If we've already fired more shots than the server says, reimburse ammo
		if player.shots_fired > player.expected_shots_fired:
			var ammo_difference: int = player.shots_fired - player.expected_shots_fired
			var ammo_to_reimburse: int = player.player_equipment.get_current_ammo() + ammo_difference
			# Reimburse the ammo
			player.player_equipment.set_current_ammo(ammo_to_reimburse)
			player.shots_fired = player.expected_shots_fired
		
		# If we haven't fired enough shots, fire them now
		elif player.shots_fired < player.expected_shots_fired:
			var shots_to_fire = player.expected_shots_fired - player.shots_fired
			
			# Ensure we're in the weapon aim state
			if not player.is_in_weapon_aim_state():
				await _ensure_weapon_raised()
			
			# We'll assume we're in the right state here
			# Fire all remaining shots
			for i in range(shots_to_fire):
				# Fire one shot
				var weapon = player.player_equipment.equipped_weapon
				var anim_name: String = weapon.get_animation()
				var play_rate: float = weapon.get_animation_play_rate()
			
				# Check ammo for this shot
				var has_ammo: bool = player.player_equipment.can_fire_weapon()
				if not has_ammo:
					play_rate = weapon.semi_fire_rate
				
				await player.player_animator.play_animation_and_await(anim_name, play_rate)
				player.shots_fired += 1
		
		# Reset count for next time
		player.expected_shots_fired = -1
	
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


func _process_rotate_action(rotation_y: float) -> void:
	# Set the rotation target
	player.player_movement.rotation_target = rotation_y
	player.player_movement.is_rotating = true
	
	# Wait for the rotation to complete
	var rotation_threshold = 0.1 # Radians (about 6 degrees)
	while abs(player.model.rotation.y - rotation_y) > rotation_threshold:
		await get_tree().process_frame
	
	# CAUTION
	# We don't send packets from this action since we are sending them from base_state.gd
	
	complete_action()


func _process_apply_damage_action(data: Dictionary) -> void:
	var target_id: int = data["target_id"]
	var damage: int = data["damage"]
	# var damage_type: String = data["damage_type"]
	var damage_position: Vector3 = data["damage_position"]
	
	# Only process if the target still exists and is alive
	if GameManager.is_player_valid(target_id):
		var target_player: Player = GameManager.get_player_by_id(target_id)
		if target_player.is_alive():
			# Regular damage, reduce health inside _aggregate_damage
			_aggregate_damage(target_id, damage, damage_position)
		else:
			clear_pending_damage_numbers(target_id)
	
	complete_action()


func _aggregate_damage(target_id: int, damage: int, damage_position: Vector3) -> void:
	if not GameManager.is_player_valid(target_id):
		return
	
	var target_player: Player = GameManager.get_player_by_id(target_id)
	if not target_player.is_alive():
		return
	
	# Decrease the health of this player right away
	target_player.decrease_health(damage)
	
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
		
		# Only process if the target still exists and is still alive
		if GameManager.is_player_valid(target_id):
			var target_player: Player = GameManager.get_player_by_id(target_id)
			if target_player.is_alive():
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
	
	# Clear pending damage numbers and damage actions for this target
	clear_pending_damage_numbers(target_id)
	_clear_pending_damage_actions(target_id)
	
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
