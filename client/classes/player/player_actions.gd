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
	if not player.is_local_player:
		print(Time.get_ticks_msec(), " ", _current_action.action_type)
	
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
		# Get the current state
		var current_state: BaseState = player.player_state_machine.get_current_state()
		if not current_state:
			complete_action()
			return
		
		# If we are in a weapon aim state, we need to lower the weapon first
		if current_state.is_weapon_aim_idle_state():
			# Queue a lower weapon action first
			add_action("lower_weapon")
			# Requeue the move action
			add_action("move", new_destination)
			complete_action()
			return
		
		var current_position: Vector2i = player.player_movement.immediate_grid_destination
		
		# Calculate path from immediate destination to new destination
		var path: Array[Vector2i] = player.player_movement.predict_path(
			current_position,
			new_destination
		)
		if path.is_empty():
			complete_action()
			return
		
		# Set up movement for the remote player
		player.player_movement.handle_remote_player_movement(path)
		
		# NOTE
		# Wait until the movement is complete before marking action as completed
		while player.player_movement.in_motion:
			await get_tree().process_frame
		
		complete_action()


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
		player.player_state_machine.get_current_state().dry_fired = true

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
	player.server_shots_fired = 0
	player.is_auto_firing = true
	
	# Start firing immediately
	current_state.next_automatic_fire()
	
	complete_action()


func _process_stop_firing_action(server_shots_fired: int) -> void:
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if not current_state:
		complete_action()
		return
	
	# Only validate local player
	if player.is_local_player:
		# Check if we can stop firing
		if not player.is_auto_firing:
			complete_action()
			return
		
		# After local validation, we send the packet
		player.player_packets.send_stop_firing_weapon_packet(
			player.player_movement.rotation_target,
			player.shots_fired
		)
	
	# For remote players, we need to ensure all shots are fired before completing
	if not player.is_local_player:
		player.server_shots_fired = server_shots_fired
		
		# If we predicted the same amount of bullets the player fired, then stop firing
		if player.shots_fired == player.server_shots_fired:
			# Reset all variables and stop firing
			player.is_auto_firing = false
			player.shots_fired = 0
			player.server_shots_fired = 0
		
		# If we fired more rounds than we were supposed to (predicting failed),
		# reimburse the ammo difference to this remote player in my own local session
		elif player.shots_fired > player.server_shots_fired:
			# Stop firing immediately
			player.is_auto_firing = false
			var ammo_difference: int = player.shots_fired - player.server_shots_fired
			var ammo_to_reimburse: int = player.player_equipment.get_current_ammo() + ammo_difference
			
			# Reset all variables
			player.shots_fired = 0
			player.server_shots_fired = 0
			player.player_equipment.set_current_ammo(ammo_to_reimburse)
		
		# If local shots fired is less than the shots the server says we need to take,
		# fire the remaining shots immediately and wait for them to complete
		elif player.shots_fired < player.server_shots_fired:
			# Stop the automatic firing loop
			player.is_auto_firing = false
			
			# Fire the remaining shots and wait for them to complete
			var shots_to_fire: int = player.server_shots_fired - player.shots_fired
			await _fire_remaining_shots_sync(shots_to_fire)
	
	if player.is_local_player:
		player.is_auto_firing = false
		player.dry_fired = false
	
	complete_action()


# Synchronously fire remaining shots - this function doesn't return until all shots are fired
func _fire_remaining_shots_sync(shots_to_fire: int) -> void:
	for i in range(shots_to_fire):
		# Check if we can still fire - if not, break out
		if not player.is_in_weapon_aim_state():
			print("Not in weapon aim state, break out of fire remaining shots sync")
			break
		
		# Fire one shot
		var weapon = player.player_equipment.equipped_weapon
		var anim_name: String = weapon.get_animation()
		var play_rate: float = weapon.get_animation_play_rate()
		
		# Check ammo for this shot
		var has_ammo: bool = player.player_equipment.can_fire_weapon()
		if not has_ammo:
			play_rate = weapon.semi_fire_rate
		
		# Play animation and wait for it to complete
		await player.player_animator.play_animation_and_await(anim_name, play_rate)
		
		player.shots_fired += 1
		
		# If we have ammo, decrement it
		if has_ammo:
			player.player_equipment.decrement_ammo()


func _process_rotate_action(rotation_y: float) -> void:
	# Set the rotation target
	player.player_movement.rotation_target = rotation_y
	player.player_movement.is_rotating = true
	
	# Wait for the rotation to complete
	var rotation_threshold = 0.05 # Radians (about 3 degrees)
	while abs(player.model.rotation.y - rotation_y) > rotation_threshold:
		await get_tree().process_frame
	
	# CAUTION
	# We don't send packets from this action since we are sending them from base_state.gd
	
	complete_action()
