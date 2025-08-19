extends Node
class_name PlayerPackets

signal packet_started(packet: Variant)

const Packets: GDScript = preload("res://packets.gd")

var player: Player = null # Our parent node

enum Priority {
	HIGH,      # Add to front
	NORMAL     # Add to back
}

var _queue: Array = []
var _current_packet: Variant = null
var _is_processing: bool = false
var _retry_count: int = 0
const MAX_RETRIES: int = 10 # Prevent infinite loops (10 ticks = 5 seconds)
var _retry_timer: Timer

const IDLE_STATES: Array[String] = [
	"idle",
	"rifle_down_idle",
]
const MOVE_STATES: Array[String] = [
	"idle",
	"move",
	"rifle_down_idle",
	"rifle_aim_idle",
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


func _on_retry_timeout() -> void:
	_retry_count = 0
	try_process_next_packet()


# Adds packet to queue with specified priority
func add_packet(packet: Variant, priority: int = Priority.NORMAL) -> void:
	match priority:
		Priority.HIGH:
			_queue.push_front(packet)
		_:
			_queue.push_back(packet)
	
	# If we are not processing a packet and our player is NOT busy
	if not _is_processing and not player.is_busy:
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
		_retry_count = 0
		_retry_timer.stop()
		try_process_current_packet()
	else:
		# Can't process now, put it back and try next
		_queue.push_front(_current_packet)
		_current_packet = null
		_is_processing = false
		
		# Only retry if we haven't exceeded max retries
		if _retry_count < MAX_RETRIES:
			_retry_count += 1
			_retry_timer.start()
		else:
			# Reset after max retries
			_retry_count = 0
			push_warning("Max retries reached for packet processing, dropping packet")
			complete_packet()


func try_process_current_packet() -> void:
	if _current_packet:
		packet_started.emit(_current_packet)
	# If our current packet is not valid, then try to process the next one
	else:
		try_process_next_packet()


# Called when current packet action completes
func complete_packet() -> void:
	if not _is_processing:
		return
	
	_current_packet = null
	_is_processing = false
	
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
	# Don't process packets if player is busy or autopilot is active
	if player.is_busy or player.player_movement.autopilot_active:
		return false
	
	# Get current state name
	var current_state_name: String = player.player_state_machine.get_current_state_name()
	
	# Only process these packets in their valid states
	if _current_packet is Packets.MoveCharacter:
		# If this is our player character, process move packets right away
		if player.my_player_character:
			return true
		# If this is a remote character, check if it can move
		else:
			return current_state_name in MOVE_STATES
	elif _current_packet is Packets.FireWeapon:
		return current_state_name in WEAPON_AIM_STATES
	elif _current_packet is Packets.StartFiringWeapon:
		return current_state_name in WEAPON_AIM_STATES
	elif _current_packet is Packets.StopFiringWeapon:
		return current_state_name in WEAPON_AIM_STATES
	elif _current_packet is Packets.RaiseWeapon:
		return current_state_name in WEAPON_DOWN_STATES
	elif _current_packet is Packets.LowerWeapon:
		return current_state_name in WEAPON_STATES
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
	else:
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
