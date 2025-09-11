extends Node
class_name PlayerPackets

signal packet_started(packet: Variant)

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


func get_packet_type(packet: Variant) -> String:
	var packet_type: String = "Unknown"
	
	# Higher priority packets
	if packet is Packets.LowerWeapon:
		packet_type = "LowerWeapon"
	elif packet is Packets.RaiseWeapon:
		packet_type = "RaiseWeapon"
	elif packet is Packets.MoveCharacter:
		packet_type = "MoveCharacter"
	elif packet is Packets.StartFiringWeapon:
		packet_type = "StartFiringWeapon"
	elif packet is Packets.StopFiringWeapon:
		packet_type = "StopFiringWeapon"
	elif packet is Packets.FireWeapon:
		packet_type = "FireWeapon"
	elif packet is Packets.RotateCharacter:
		packet_type = "RotateCharacter"
	# Lower priority packets
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
	
	# If we are not processing a packet
	if not _is_processing:
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
		# Reset timeout and max retry variables for packet processing
		_packet_process_timeout = 0
		_retry_count = 0
		_retry_timer.stop()
		try_process_current_packet()
	
	# Can't process the packet now
	else:
		# Check if we hit the retry limit or the packet timeout
		if _retry_count > MAX_RETRIES or _packet_process_timeout > MAX_PACKET_PROCESSING_TIMEOUT:
			if _current_packet:
				# DEBUG dropping packet of remote player
				if not player.my_player_character:
					print("[REMOTE] %s -> Dropping %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
				
				# Drop the current packet
				_current_packet = null
				_is_processing = false
				GameManager.packets_lost += 1
				complete_packet() # This tries to process the next packet immediately
		
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
		#if not player.my_player_character:
			#print("[REMOTE] %s -> Processing %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
		
		packet_started.emit(_current_packet)
	# If our current packet is not valid, then try to process the next one
	else:
		push_error("try_process_current_packet not valid, processing next_packet instead")
		try_process_next_packet()


# Called when current packet action completes
func complete_packet() -> void:
	if not _is_processing:
		return
	
	# Reset timeout and max retry variables for packet processing
	_packet_process_timeout = 0
	_retry_timer.stop()
	_retry_count = 0
	
	# DEBUG completing packet of remote player
	#if not player.my_player_character:
	#	print("[REMOTE] %s -> Completing %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
	
	_current_packet = null
	_is_processing = false
	
	# Await a frame to let the player state machine to catch up
	await get_tree().process_frame
	
	# Try to process next packet immediately after completing
	try_process_next_packet()


# Get current processing state
func is_processing_packet() -> bool:
	return _is_processing


# Clear all pending packets
func clear() -> void:
	_queue.clear()
	_current_packet = null
	_is_processing = false


# Get method for the current_packet
func get_current_packet() -> Variant:
	return _current_packet


# Determines if the current packet can be processed right away
func can_process_packet() -> bool:
	# Don't process packets if player is busy
	if player.is_busy:
		return false
	# Don't process packets if autopilot is active
	if player.player_movement.autopilot_active:
		return false
	
	# Get current state name
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	
	# Only process these packets in their valid states
	# LOWER WEAPON
	if _current_packet is Packets.LowerWeapon:
		# Allow lowering weapon only in aim states
		return current_state_name in WEAPON_AIM_STATES
	
	# RAISE WEAPON
	elif _current_packet is Packets.RaiseWeapon:
		# Allow raising weapon only in down states
		return current_state_name in WEAPON_DOWN_STATES
	
	# MOVE CHARACTER
	elif _current_packet is Packets.MoveCharacter:
		return current_state_name in MOVE_STATES
	
	# START AUTOMATIC FIRE WEAPON
	elif _current_packet is Packets.StartFiringWeapon:
		return current_state_name in WEAPON_AIM_STATES
	
	# STOP AUTOMATIC FIRE WEAPON
	elif _current_packet is Packets.StopFiringWeapon:
		return current_state_name in WEAPON_AIM_STATES
	
	# SINGLE FIRE WEAPON
	elif _current_packet is Packets.FireWeapon:
		return current_state_name in WEAPON_AIM_STATES
	
	# Lower priority packets
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
