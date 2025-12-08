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


const IDLE_STATES: Array[String] = [
	"unarmed_idle",
	"unarmed_crouch_idle",
	"rifle_down_idle",
]
const MOVE_STATES: Array[String] = [
	"unarmed_idle",
	"unarmed_crouch_idle",
	"move",
	"rifle_down_idle",
]
const WEAPON_STATES: Array[String] = [
	"rifle_down_idle",
	"rifle_aim_idle",
	"rifle_crouch_down_idle",
	"rifle_crouch_aim_idle",
	"shotgun_down_idle",
	"shotgun_aim_idle",
	"shotgun_crouch_down_idle",
	"shotgun_crouch_aim_idle",
]
const WEAPON_DOWN_STATES: Array[String] = [
	"rifle_down_idle",
	"rifle_crouch_down_idle",
	"shotgun_down_idle",
	"shotgun_crouch_down_idle",
]
const WEAPON_AIM_STATES: Array[String] = [
	"rifle_aim_idle",
	"rifle_crouch_aim_idle",
	"shotgun_aim_idle",
	"shotgun_crouch_aim_idle",
]


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	# Wait a single frame to allow time for the other player components to load
	await get_tree().process_frame
	player = get_parent()
	
	# Do this only for my local player
	if player.is_local_player:
		Signals.ui_change_move_speed_button.connect(handle_signal_ui_update_speed_button)


func get_packet_type(packet: Variant) -> String:
	var packet_type: String = "Unknown"
	
	# If the packet is not valid, ignore
	if not packet:
		return packet_type
	
	if packet is Packets.MoveCharacter:
		packet_type = "MoveCharacter"
	elif packet is Packets.LowerWeapon:
		packet_type = "LowerWeapon"
	elif packet is Packets.RaiseWeapon:
		packet_type = "RaiseWeapon"
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
	elif packet is Packets.CrouchCharacter:
		packet_type = "CrouchCharacter"
	elif packet is Packets.ApplyPlayerDamage:
		packet_type = "ApplyPlayerDamage"
	elif packet is Packets.SpawnCharacter:
		packet_type = "SpawnCharacter"
	elif packet is Packets.PlayerDied:
		packet_type = "PlayerDied"
	
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
	#if not player.is_local_player:
		#print("[REMOTE] %s -> Adding %s packet to queue, current_state: %s, at: %d" % [player.player_name, get_packet_type(packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
	
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
	
	try_process_current_packet()


func try_process_current_packet() -> void:
	if _current_packet:
		# DEBUG processing packet of remote player
		#if not player.is_local_player:
			#print("[REMOTE] %s -> Processing %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
		
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
	#if not player.is_local_player:
		#if _current_packet:
			#print("[REMOTE] %s -> Completing %s packet, current_state: %s at: %d" % [player.player_name, get_packet_type(_current_packet), player.player_state_machine.get_current_state_name(), Time.get_ticks_msec()])
	
	_current_packet = null
	_is_processing = false
	
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


func route_packet_to_action_queue(action_type: String, action_data: Variant = null) -> void:
	# Add the action to the queue
	player.player_actions.add_action(action_type, action_data)
	# Complete the packet immediately since we already queued the action
	complete_packet()


func can_process_packet() -> bool:
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
func create_rotate_character_packet(rotation_y: float, await_rotation: bool = true) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var rotate_character_packet := packet.new_rotate_character()
	rotate_character_packet.set_rotation_y(rotation_y)
	rotate_character_packet.set_await_rotation(await_rotation)
	return packet


# Creates and returns a fire_weapon packet
func create_fire_weapon_packet(target: Vector3) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var fire_weapon_packet := packet.new_fire_weapon()
	# Set target
	fire_weapon_packet.set_x(target.x)
	fire_weapon_packet.set_y(target.y)
	fire_weapon_packet.set_z(target.z)
	return packet


# Creates and returns a toggle_fire_mode packet
func create_toggle_fire_mode_packet() -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	packet.new_toggle_fire_mode()
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


# Creates and returns a respawn_request packet
func create_respawn_request_packet(region_id: int = 0, desired_position: Vector2i = Vector2i(-1, -1)) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var respawn_request_packet := packet.new_respawn_request()
	respawn_request_packet.set_region_id(region_id)
	
	# If desired position is provided, add it to the packet
	if desired_position != Vector2i(-1, -1):
		respawn_request_packet.set_x(desired_position.x)
		respawn_request_packet.set_z(desired_position.y)
	
	return packet


# Creates and returns a crouch_character packet
func create_crouch_character_packet(is_crouching: bool) -> Packets.Packet:
	var packet: Packets.Packet = Packets.Packet.new()
	var crouch_character_packet := packet.new_crouch_character()
	crouch_character_packet.set_is_crouching(is_crouching)
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
func send_rotate_character_packet(rotation_y: float, await_rotation: bool = true) -> void:
	var packet: Packets.Packet = create_rotate_character_packet(rotation_y, await_rotation)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we fired our weapon
func send_fire_weapon_packet(target: Vector3) -> void:
	var packet: Packets.Packet = create_fire_weapon_packet(target)
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we switched our fire mode
func send_toggle_fire_mode_packet() -> void:
	var packet: Packets.Packet = create_toggle_fire_mode_packet()
	WebSocket.send(packet)


# Creates and sends a packet to the server to inform we shot a player
func send_report_player_damage_packet(target_id: int, hit_position: Vector3, is_critical: bool) -> void:
	var packet: Packets.Packet = create_report_player_damage_packet(target_id, hit_position, is_critical)
	WebSocket.send(packet)


# Creates and sends a packet  to the server to report our new immediate destination
func send_destination_packet(destination: Vector2i) -> void:
	var packet: Packets.Packet = player.player_packets.create_destination_packet(destination)
	WebSocket.send(packet)


# Creates and sends a packet to the server requesting to respawn
func send_respawn_request_packet(region_id: int = 0, desired_position: Vector2i = Vector2i(-1, -1)) -> void:
	var packet: Packets.Packet = create_respawn_request_packet(region_id, desired_position)
	WebSocket.send(packet)


# Creates and sends a packet to the server to report character crouch state
func send_crouch_character_packet(is_crouching: bool) -> void:
	var packet: Packets.Packet = create_crouch_character_packet(is_crouching)
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
	elif packet is Packets.CrouchCharacter:
		_process_crouch_character_packet(packet)
	elif packet is Packets.ApplyPlayerDamage:
		_process_apply_player_damage_packet(packet)
	elif packet is Packets.SpawnCharacter:
		_process_spawn_character_packet(packet)
	elif packet is Packets.PlayerDied:
		_process_player_died_packet(packet)
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
	
	# Remove the player from the grid position it wase
	RegionManager.remove_object(previous_position)
	# Add the player to the new position in my local grid
	RegionManager.set_object(server_position, self)
	
	# Update server position for both local and remote players
	player.player_movement.server_grid_position = server_position
	
	route_packet_to_action_queue("move", server_position)


# Updates the player's move speed to match the server's
func _process_update_speed_packet(packet: Packets.UpdateSpeed) -> void:
	var new_speed: int = packet.get_speed()
	
	# Only allow speed changes when not moving
	if not player.player_movement.in_motion:
		# Clamp speed to 1-3 range
		player.player_speed = clamp(new_speed, 1, 3)
	
	complete_packet()


func _process_switch_weapon_packet(packet: Packets.SwitchWeapon) -> void:
	route_packet_to_action_queue("switch_weapon", packet.get_slot())


func _process_reload_weapon_packet(packet: Packets.ReloadWeapon) -> void:
	route_packet_to_action_queue("reload_weapon", {"amount": packet.get_amount()})


func _process_raise_weapon_packet() -> void:
	route_packet_to_action_queue("raise_weapon")


func _process_lower_weapon_packet() -> void:
	route_packet_to_action_queue("lower_weapon")


func _process_rotate_character_packet(packet: Packets.RotateCharacter) -> void:
	route_packet_to_action_queue("rotate", packet)


func _process_fire_weapon_packet(packet: Packets.FireWeapon) -> void:
	# Extract hit position from the packet
	var target: Vector3 = Vector3(packet.get_x(), packet.get_y(), packet.get_z())
	
	player.player_actions.add_action("single_fire", target)
	
	complete_packet()


func _process_toggle_fire_mode_packet() -> void:
	route_packet_to_action_queue("toggle_fire_mode")


func _process_crouch_character_packet(packet: Packets.CrouchCharacter) -> void:
	if packet.get_is_crouching():
		player.player_actions.add_action("enter_crouch")
	else:
		player.player_actions.add_action("leave_crouch")
	
	complete_packet()


func _process_apply_player_damage_packet(packet: Packets.ApplyPlayerDamage) -> void:
	var data = {
		"target_id": packet.get_target_id(),
		"damage": packet.get_damage(),
		"damage_type": packet.get_damage_type(),
		"damage_position": Vector3(
			packet.get_x(),
			packet.get_y(),
			packet.get_z())
	}
	route_packet_to_action_queue("apply_damage", data)
	
	complete_packet()


func _process_spawn_character_packet(packet: Packets.SpawnCharacter) -> void:
	route_packet_to_action_queue("respawn", packet)
	complete_packet()


func _process_player_died_packet(packet: Packets.PlayerDied) -> void:
	route_packet_to_action_queue("death", packet)
	complete_packet()
