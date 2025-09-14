extends Node
class_name PlayerPackets

const Packets: GDScript = preload("res://packets.gd")

var player: Player = null # Our parent node

enum Priority {
	HIGH,      # Add to front
	NORMAL     # Add to back
}

# NOTE
# We use a dual system that tries to process the next packet in the queue every half a second
# but also check the packet doesn't timeout (10 second limit).
var _queue: Array = []
var _current_packet: Variant = null
var _is_processing: bool = false
# Prevent the packet queue to hanging due to infinite retries
var _retry_count: int = 0
const MAX_RETRIES: int = 10 # Prevent infinite loops (10 ticks = 5 seconds)
var _retry_timer: Timer
# Prevent the packet queue from hanging due to uncaught errors
var _packet_process_timeout: float = 0
const MAX_PACKET_PROCESSING_TIMEOUT: float = 5.0 # 10 second timeout


const IDLE_STATES: Array[String] = [
	"idle",
	"rifle_down_idle",
]
const MOVE_STATES: Array[String] = [
	"idle",
	"move",
	"rifle_down_idle",
]
const WEAPON_STATES: Array[String] = [
	"rifle_down_idle",
	"rifle_aim_idle",
]
const WEAPON_DOWN_STATES: Array[String] = [
	"rifle_down_idle",
]
const WEAPON_AIM_STATES: Array[String] = [
	"rifle_aim_idle",
]


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	# Wait a single frame to allow time for the other player components to load
	await get_tree().process_frame
	player = get_parent()
	
	# Create retry timer
	_retry_timer = Timer.new()
	_retry_timer.wait_time = 0.5 # 500ms
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_on_retry_timeout)
	add_child(_retry_timer)
	
	# Do this only for my local player
	if player.my_player_character:
		Signals.ui_change_move_speed_button.connect(handle_signal_ui_update_speed_button)


# Track packet processing timeout
func _process(delta: float) -> void:
	if _is_processing:
		_packet_process_timeout += delta
	else:
		_packet_process_timeout = 0


# Resets timeout and max retry variables for packet processing
func reset_packet_timeout() -> void:
	_packet_process_timeout = 0
	_retry_count = 0
	_retry_timer.stop()


func get_packet_type(packet: Variant) -> String:
	var packet_type: String = "Unknown"
	
	if packet is Packets.MoveCharacter:
		packet_type = "MoveCharacter"
	elif packet is Packets.LowerWeapon:
		packet_type = "LowerWeapon"
	elif packet is Packets.RaiseWeapon:
		packet_type = "RaiseWeapon"
	elif packet is Packets.StartFiringWeapon:
		packet_type = "StartFiringWeapon"
	elif packet is Packets.StopFiringWeapon:
		packet_type = "StopFiringWeapon"
	elif packet is Packets.FireWeapon:
		packet_type = "FireWeapon"
	elif packet is Packets.RotateCharacter:
		packet_type = "RotateCharacter"
	elif packet is Packets.UpdateSpeed:
		packet_type = "UpdateSpeed"
	elif packet is Packets.SwitchWeapon:
		packet_type = "SwitchWeapon"
	elif packet is Packets.ReloadWeapon:
		packet_type = "ReloadWeapon"
	elif packet is Packets.ToggleFireMode:
		packet_type = "ToggleFireMode"
	
	# Packets that get processed in any state
	elif packet is Packets.ApplyPlayerDamage:
		packet_type = "ApplyPlayerDamage"
	
	# If not on the list, report it as an error to add it
	if packet_type == "Unknown":
		push_error("Unknown packet: ", packet)
	
	return packet_type



# Adds packet to queue with specified priority
func add_packet(packet: Variant, priority: int = Priority.NORMAL) -> void:
	# DEBUG adding packet to remote player
	if not player.my_player_character:
		print("[REMOTE] %s -> Adding %s packet to queue, current_state: %s, at: %d" % [player.player_name, get_packet_type(packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
	
	match priority:
		Priority.HIGH:
			_queue.push_front(packet)
		_:
			_queue.push_back(packet)
	
	try_process_next_packet()


# Process next packet if available
func try_process_next_packet() -> void:
	if _is_processing or _queue.is_empty():
		return
	
	# Get the next packet
	_current_packet = _queue.pop_front()
	_is_processing = true
	
	# Check if we can process this packet now
	if can_process_packet():
		reset_packet_timeout()
		try_process_current_packet()
	
	# Can't process the packet now
	else:
		# Check if we hit the retry limit or the packet timeout
		if _retry_count > MAX_RETRIES or _packet_process_timeout > MAX_PACKET_PROCESSING_TIMEOUT:
			reset_packet_timeout()
			if _current_packet:
				# DEBUG dropping packet of remote player
				if not player.my_player_character:
					print("[REMOTE] %s -> Dropping %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
				
				GameManager.packets_lost += 1
				
				# Drop the current packet and process the next one
				complete_packet()
		
		# If we haven't reach the limit
		else:
			# Add the packet to the front of the queue and try again in one server tick
			_queue.push_front(_current_packet)
			_current_packet = null
			_is_processing = false
			# Increment retry count by 1 tick
			_retry_count += 1
			# Restart the timer so we try in 1 server tick again
			_retry_timer.start()


func _on_retry_timeout() -> void:
	try_process_next_packet()


func try_process_current_packet() -> void:
	if _current_packet:
		# DEBUG processing packet of remote player
		if not player.my_player_character:
			print("[REMOTE] %s -> Processing %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
		
		# NOTE
		# Process packet
		_handle_packet_started(_current_packet)
	# If our current packet is not valid, then try to process the next one
	else:
		push_error("try_process_current_packet not valid, processing next_packet instead")
		_current_packet = null
		_is_processing = false
		try_process_next_packet()


# Called when current packet action completes
func complete_packet() -> void:
	# DEBUG completing packet of remote player
	if not player.my_player_character:
		print("[REMOTE] %s -> Completing %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
	
	_current_packet = null
	_is_processing = false
	
	reset_packet_timeout()
	# Try to process next packet immediately after completing
	try_process_next_packet()


# Get current processing state
func is_processing_packet() -> bool:
	return _is_processing


# Clear all pending packets
func clear() -> void:
	_current_packet = null
	_is_processing = false
	_queue.clear()


# Get method for the current_packet
func get_current_packet() -> Variant:
	return _current_packet


func get_current_packet_type() -> String:
	var packet: Variant = get_current_packet()
	if packet:
		return get_packet_type(get_current_packet())
	return "Unknown"


# Determines if the current packet can be processed right away
func can_process_packet() -> bool:
	# Get current state name
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	
	# MOVE CHARACTER
	if _current_packet is Packets.MoveCharacter:
		if player.my_player_character:
			return true
		else:
			if current_state_name in WEAPON_AIM_STATES:
				print("Character trying to move while in aim state, force lowering weapon")
				player.player_state_machine.get_current_state().lower_weapon_and_await(false)
			return current_state_name in MOVE_STATES
	
	# Only process these packets in their valid states
	# LOWER WEAPON
	elif _current_packet is Packets.LowerWeapon:
		# Allow lowering weapon only in aim states
		return current_state_name in WEAPON_STATES
	
	# RAISE WEAPON
	elif _current_packet is Packets.RaiseWeapon:
		# Allow raising weapon only in down states
		return current_state_name in WEAPON_STATES
	
	# START AUTOMATIC FIRE WEAPON
	elif _current_packet is Packets.StartFiringWeapon:
		if current_state_name in WEAPON_DOWN_STATES:
			print("Character trying to start auto fire while in an idle state, force raising weapon")
			player.player_state_machine.get_current_state().raise_weapon_and_await(false)
		return current_state_name in WEAPON_AIM_STATES
	
	# STOP AUTOMATIC FIRE WEAPON
	elif _current_packet is Packets.StopFiringWeapon:
		if current_state_name in WEAPON_DOWN_STATES:
			print("Character trying to stop auto fire while in an idle state, force raising weapon")
			player.player_state_machine.get_current_state().raise_weapon_and_await(false)
		return current_state_name in WEAPON_AIM_STATES
	
	# SINGLE FIRE WEAPON
	elif _current_packet is Packets.FireWeapon:
		if current_state_name in WEAPON_DOWN_STATES:
			print("Character trying to start single fire while in an idle state, force raising weapon")
			player.player_state_machine.get_current_state().raise_weapon_and_await(false)
		return current_state_name in WEAPON_AIM_STATES
	
	elif _current_packet is Packets.UpdateSpeed:
		return current_state_name in IDLE_STATES
	elif _current_packet is Packets.SwitchWeapon:
		return current_state_name in IDLE_STATES
	elif _current_packet is Packets.ReloadWeapon:
		return current_state_name in WEAPON_STATES
	elif _current_packet is Packets.ToggleFireMode:
		return current_state_name in WEAPON_STATES

	# Allow other packets by default
	return true


###################
# PACKET CREATION #
###################

# Creates and returns a destination_packet
func create_destination_packet(grid_pos: Vector2i) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var destination_packet := packet.new_destination()
	destination_packet.set_x(grid_pos.x)
	destination_packet.set_z(grid_pos.y)
	return packet


# Creates and returns an update_speed packet
func create_update_speed_packet(new_speed: int) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var update_speed_packet := packet.new_update_speed()
	update_speed_packet.set_speed(new_speed)
	return packet


# Creates and returns a join_region_request packet
func create_join_region_request_packet(region_id: int) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var join_region_request_packet := packet.new_join_region_request()
	join_region_request_packet.set_region_id(region_id)
	return packet


# Creates and returns a switch_weapon packet
func create_switch_weapon_packet(weapon_slot: int) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var switch_weapon_packet := packet.new_switch_weapon()
	switch_weapon_packet.set_slot(weapon_slot)
	return packet


# Creates and returns a reload_weapon packet
func create_reload_weapon_packet(weapon_slot: int, amount: int) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var reload_weapon_packet := packet.new_reload_weapon()
	reload_weapon_packet.set_slot(weapon_slot)
	reload_weapon_packet.set_amount(amount)
	return packet


# Creates and returns a raise_weapon packet
func create_raise_weapon_packet() -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	packet.new_raise_weapon()
	return packet


# Creates and returns a lower_weapon packet
func create_lower_weapon_packet() -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	packet.new_lower_weapon()
	return packet


# Creates and returns a rotate_character packet
func create_rotate_character_packet(rotation_y: float) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var rotate_character_packet := packet.new_rotate_character()
	rotate_character_packet.set_rotation_y(rotation_y)
	return packet


# Creates and returns a fire_weapon packet
func create_fire_weapon_packet(target: Vector3, rotation_y: float) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var fire_weapon_packet := packet.new_fire_weapon()
	# Set target
	fire_weapon_packet.set_x(target.x)
	fire_weapon_packet.set_y(target.y)
	fire_weapon_packet.set_z(target.z)
	# Set shooter's rotation
	fire_weapon_packet.set_rotation_y(rotation_y)
	return packet


# Creates and returns a toggle_fire_mode packet
func create_toggle_fire_mode_packet() -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	packet.new_toggle_fire_mode()
	return packet


# Creates and returns a start_firing_weapon packet
func create_start_firing_weapon_packet(rotation_y: float, ammo: int) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var start_firing_weapon_packet := packet.new_start_firing_weapon()
	start_firing_weapon_packet.set_rotation_y(rotation_y)
	start_firing_weapon_packet.set_ammo(ammo)
	return packet


# Creates and returns a stop_firing_weapon packet
func create_stop_firing_weapon_packet(rotation_y: float, shots_fired: int) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var stop_firing_weapon_packet := packet.new_stop_firing_weapon()
	stop_firing_weapon_packet.set_rotation_y(rotation_y)
	stop_firing_weapon_packet.set_shots_fired(shots_fired)
	return packet


# Creates and returns a report_player_damage packet
func create_report_player_damage_packet(target_id: int, hit_position: Vector3, is_critical: bool) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var report_player_damage_packet := packet.new_report_player_damage()
	report_player_damage_packet.set_target_id(target_id)
	report_player_damage_packet.set_x(hit_position.x)
	report_player_damage_packet.set_y(hit_position.y)
	report_player_damage_packet.set_z(hit_position.z)
	report_player_damage_packet.set_is_critical(is_critical)
	return packet


##################
# PACKET SENDING #
##################

# Creates and sends a packet to the server requesting to switch regions/maps
func request_switch_region(new_region: int) -> void:
	var packet: Packets.Packet = create_join_region_request_packet(new_region)
	WebSocket.send(packet)


# Request the server to change the movement speed of my player
func handle_signal_ui_update_speed_button(new_move_speed: int) -> void:
	var packet: Packets.Packet = create_update_speed_packet(new_move_speed)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we switched our weapon
func send_switch_weapon_packet(weapon_slot: int) -> void:
	var packet: Packets.Packet = create_switch_weapon_packet(weapon_slot)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we reloaded our weapon
func send_reload_weapon_packet(weapon_slot: int, amount: int) -> void:
	var packet: Packets.Packet = create_reload_weapon_packet(weapon_slot, amount)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we raised our weapon
func send_raise_weapon_packet() -> void:
	var packet: Packets.Packet = create_raise_weapon_packet()
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we lowered our weapon
func send_lower_weapon_packet() -> void:
	var packet: Packets.Packet = create_lower_weapon_packet()
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we rotated
func send_rotate_character_packet(rotation_y: float) -> void:
	var packet: Packets.Packet = create_rotate_character_packet(rotation_y)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we fired our weapon
func send_fire_weapon_packet(target: Vector3, rotation_y: float) -> void:
	var packet: Packets.Packet = create_fire_weapon_packet(target, rotation_y)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we switched our fire mode
func send_toggle_fire_mode_packet() -> void:
	var packet: Packets.Packet = create_toggle_fire_mode_packet()
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we started firing
func send_start_firing_weapon_packet(rotation_y: float, ammo: int) -> void:
	var packet: Packets.Packet = create_start_firing_weapon_packet(rotation_y, ammo)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we stopped firing
func send_stop_firing_weapon_packet(rotation_y: float, shots_fired: int) -> void:
	var packet: Packets.Packet = create_stop_firing_weapon_packet(rotation_y, shots_fired)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we shot a player
func send_report_player_damage_packet(target_id: int, hit_position: Vector3, is_critical: bool) -> void:
	var packet: Packets.Packet = create_report_player_damage_packet(target_id, hit_position, is_critical)
	WebSocket.send(packet)


# Creates and sends a packet  to the server to report our new immediate destination
func send_destination_packet(destination: Vector2i) -> void:
	var packet: Packets.Packet = player.player_packets.create_destination_packet(destination)
	WebSocket.send(packet)



#####################
# PACKET PROCESSING #
#####################


func _handle_packet_started(packet: Variant) -> void:
	if packet is Packets.MoveCharacter:
		_process_move_character_packet(packet)
	elif packet is Packets.LowerWeapon:
		_process_lower_weapon_packet()
	elif packet is Packets.RaiseWeapon:
		_process_raise_weapon_packet()
	elif packet is Packets.StartFiringWeapon:
		_process_start_firing_weapon_packet(packet)
	elif packet is Packets.StopFiringWeapon:
		process_stop_firing_weapon_packet(packet)
	elif packet is Packets.FireWeapon:
		_process_fire_weapon_packet(packet)
	elif packet is Packets.RotateCharacter:
		_process_rotate_character_packet(packet)
	
	elif packet is Packets.UpdateSpeed:
		_process_update_speed_packet(packet)
	elif packet is Packets.SwitchWeapon:
		_process_switch_weapon_packet(packet)
	elif packet is Packets.ReloadWeapon:
		_process_reload_weapon_packet(packet)
	elif packet is Packets.ToggleFireMode:
		_process_toggle_fire_mode_packet()
	else:
		complete_packet() # Unknown packet


# Updates the character's server grid position
func _process_move_character_packet(packet: Packets.MoveCharacter) -> void:
	var server_position: Vector2i = Vector2i(
		packet.get_position().get_x(),
		packet.get_position().get_z()
	)
	
	# Store the previous position before updating anything
	var previous_position: Vector2i = player.player_movement.server_grid_position
	
	# Remove the player from the grid position it was
	RegionManager.remove_object(previous_position, self)
	# Add the player to the new position in my local grid
	RegionManager.set_object(server_position, self)
	
	# Only do the reconciliation for my player
	if player.my_player_character:
		player.player_movement.handle_server_reconciliation(server_position)
	# Remote players are always in sync with the server
	else:
		player.player_movement.handle_remote_player_movement(server_position)
	
	if is_processing_packet():
		# If we were processing a MoveCharacter packet, complete it
			if _current_packet is Packets.MoveCharacter:
				complete_packet()


# Updates the player's move speed to match the server's
func _process_update_speed_packet(packet: Packets.UpdateSpeed) -> void:
	var new_speed: int = packet.get_speed()
	
	# Only allow speed changes when not moving
	if not player.player_movement.in_motion:
		# Clamp speed to 1-3 range
		player.player_speed = clamp(new_speed, 1, 3)
	
	complete_packet()


func _process_switch_weapon_packet(packet: Packets.SwitchWeapon) -> void:
	var slot = packet.get_slot()
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Call without broadcast since this came from server
		current_state.switch_weapon(slot, false)
		# Completion will be handled by the state machine
	else:
		# If no state available, complete immediately
		complete_packet()


func _process_reload_weapon_packet(packet: Packets.ReloadWeapon) -> void:
	var slot = packet.get_slot()
	var amount = packet.get_amount()
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Call without broadcast since this came from server
		await current_state.reload_weapon_and_await(slot, amount, false)
		# Completion will be handled by the state machine
	else:
		# If no state available, complete immediately
		complete_packet()


func _process_raise_weapon_packet() -> void:
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Call without broadcast since this came from server
		await current_state.raise_weapon_and_await(false)
		# Completion will be handled by the state machine
	else:
		# If no state available, complete immediately
		complete_packet()


func _process_lower_weapon_packet() -> void:
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Call without broadcast since this came from server
		await current_state.lower_weapon_and_await(false)
		# Completion will be handled by the state machine
	else:
		# If no state available, complete immediately
		complete_packet()


func _process_rotate_character_packet(packet: Packets.RotateCharacter) -> void:
	var new_rotation: float = packet.get_rotation_y()
	player.player_movement.rotation_target = new_rotation
	player.player_movement.is_rotating = true
	# Complete the packet right away
	complete_packet()


func _process_fire_weapon_packet(packet: Packets.FireWeapon) -> void:
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Extract shooter's rotation from the packet
		var rotation_y: float = packet.get_rotation_y()
		# Update rotation before shooting
		player.player_movement.rotation_target = rotation_y
		player.player_movement.is_rotating = true
		# Extract target position
		var target: Vector3 = Vector3(packet.get_x(), packet.get_y(), packet.get_z())
		# Call without broadcast since this came from server
		current_state.single_fire(target, false)
		# Completion will be handled by the state machine
	else:
		# If no state available, complete immediately
		complete_packet()


func _process_toggle_fire_mode_packet() -> void:
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Call without broadcast since this came from server
		current_state.toggle_fire_mode(false)
		# Completion will be handled by the state machine
	else:
		# If no state available, complete immediately
		complete_packet()


func _process_start_firing_weapon_packet(packet: Packets.StartFiringWeapon) -> void:
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Extract shooter's rotation from the packet
		var rotation_y: float = packet.get_rotation_y()
		# Update rotation before shooting
		player.player_movement.rotation_target = rotation_y
		player.player_movement.is_rotating = true
		# Extract the shooter's current ammo from the packet
		player.player_equipment.set_current_ammo(packet.get_ammo())
		# Call without broadcast since this came from server
		current_state.start_automatic_firing(false)
		# Completion will be handled by the state machine
	else:
		# If no state available, complete immediately
		complete_packet()


func process_stop_firing_weapon_packet(packet: Packets.StopFiringWeapon) -> void:
	var current_state: BaseState = player.player_state_machine.get_current_state()
	
	if current_state:
		# Extract shooter's rotation from the packet
		var rotation_y: float = packet.get_rotation_y()
		# Update rotation before shooting
		player.player_movement.rotation_target = rotation_y
		player.player_movement.is_rotating = true
		# Extract the amount of shots taken until we stopped to keep remote players synced
		var server_shots_fired: int = packet.get_shots_fired()
		current_state.server_shots_fired = server_shots_fired
		# Call without broadcast since this came from server
		current_state.stop_automatic_firing(false)
	
	# Always complete the packet after processing
	complete_packet()
