extends Node
class_name PlayerPackets

signal packet_started(packet: Variant)
signal packet_completed(packet: Variant)

const Packets: GDScript = preload("res://packets.gd")

var player: Player = null # Our parent node

enum Priority {
	HIGH,      # Add to front
	NORMAL     # Add to back
}

var _queue: Array = []
var _current_packet: Variant = null
var _is_processing: bool = false


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	player = get_parent()
	
	# Do this only for my local player
	if player.my_player_character:
		Signals.ui_change_move_speed_button.connect(handle_signal_ui_update_speed_button)


# Adds packet to queue with specified priority
func add_packet(packet: Variant, priority: int = Priority.NORMAL) -> void:
	match priority:
		Priority.HIGH:
			_queue.push_front(packet)
		_:
			_queue.push_back(packet)
	
	# If we are not processing and the queue only has one packet
	if not _is_processing:
		_try_process_next()


# Process next packet if available
func _try_process_next() -> void:
	if _is_processing or _queue.is_empty():
		return
	
	_current_packet = _queue.pop_front()
	_is_processing = true
	packet_started.emit(_current_packet)


# Called when current packet action completes
func complete_packet() -> void:
	if not _is_processing:
		return
	
	_current_packet = null
	_is_processing = false
	
	_try_process_next()


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

###################
# PACKET CREATION #
###################

# Creates and returns a player_destination_packet
func create_player_destination_packet(grid_pos: Vector2i) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var player_destination_packet := packet.new_player_destination()
	player_destination_packet.set_x(grid_pos.x)
	player_destination_packet.set_z(grid_pos.y)
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


################
# PACKETS SENT #
################

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
