extends Node

# Preload scripts
const Packets: GDScript = preload("res://packets.gd")
const GameEscapeMenu: GDScript = preload("res://components/escape_menu/game/game_escape_menu.gd")
const GameControlsMenu: GDScript = preload("res://components/controls_menu/game/game_controls_menu.gd")

# Preload scenes
const game_escape_menu_scene: PackedScene = preload("res://components/escape_menu/game/game_escape_menu.tscn")
const GAME_CONTROLS_MENU = preload("res://components/controls_menu/game/game_controls_menu.tscn")

# Holds our current map node so we can spawn scenes into it
var _current_map_scene: Node

# User Interface Variables
@onready var ui_canvas: CanvasLayer = $UI
@onready var chat: Control = $UI/VBoxContainer/Chat

var chat_container: VBoxContainer
var chat_input: LineEdit
var game_escape_menu: GameEscapeMenu
var game_controls_menu: GameControlsMenu


func _ready() -> void:
	_initialize()


func _initialize() -> void:
	# Get access to the child nodes of the chat UI
	chat_container = chat.find_child("ChatContainer")
	chat_input = chat.find_child("ChatInput")
	
	_create_ui_scenes()
	
	# Websocket signals
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)
	Signals.heartbeat_attempt.connect(_on_websocket_heartbeat_attempt)
	# User Interface signals
	Signals.ui_escape_menu_toggle.connect(_on_ui_escape_menu_toggle)
	Signals.ui_logout.connect(_handle_signal_ui_logout)
	Signals.ui_controls_menu_toggle.connect(_handle_signal_ui_controls_menu_toggle)
	# Chat signals
	Signals.chat_public_message_sent.connect(_handle_signal_chat_public_message_sent)
	


func _create_ui_scenes() -> void:
	# Create and add each UI scene to the UI canvas layer, hidden
	game_escape_menu = game_escape_menu_scene.instantiate()
	ui_canvas.add_child(game_escape_menu)
	
	game_controls_menu = GAME_CONTROLS_MENU.instantiate()
	ui_canvas.add_child(game_controls_menu)


# If our connection to the server closed
func _on_websocket_connection_closed() -> void:
	chat.error("You have been disconnected from the server")
	# CAUTION
	# Display a dialog box that the user can accept to go back to main menu


func _on_websocket_packet_received(packet: Packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	
	# HIGHER PRIORITY PACKETS THAT GET QUEUED
	if packet.has_move_character():
		_route_move_character_packet(sender_id, packet.get_move_character())
	elif packet.has_fire_weapon():
		_route_fire_weapon_packet(sender_id, packet.get_fire_weapon())
	elif packet.has_start_firing_weapon():
		_route_start_firing_weapon_packet(sender_id, packet.get_start_firing_weapon())
	elif packet.has_stop_firing_weapon():
		_route_stop_firing_weapon_packet(sender_id, packet.get_stop_firing_weapon())
	elif packet.has_rotate_character():
		_route_rotate_character_packet(sender_id, packet.get_rotate_character())
	elif packet.has_raise_weapon():
		_route_raise_weapon_packet(sender_id, packet.get_raise_weapon())
	elif packet.has_lower_weapon():
		_route_lower_weapon_packet(sender_id, packet.get_lower_weapon())
	# LOWER PRIORITY PACKETS THAT GET QUEUED
	elif packet.has_update_speed():
		_route_update_speed_packet(sender_id, packet.get_update_speed())
	elif packet.has_switch_weapon():
		_route_switch_weapon_packet(sender_id, packet.get_switch_weapon())
	elif packet.has_reload_weapon():
		_route_reload_weapon_packet(sender_id, packet.get_reload_weapon())
	elif packet.has_toggle_fire_mode():
		_route_toggle_fire_mode_packet(sender_id, packet.get_toggle_fire_mode())
	
	# IMMEDIATE PACKETS DON'T GO INTO PACKET QUEUE
	# PACKETS THAT NEED CLIENT_ID INSIDE THE PACKET
	if packet.has_spawn_character():
		_handle_spawn_character_packet(packet.get_spawn_character())
	elif packet.has_region_data():
		_handle_region_data_packet(packet.get_region_data())
	elif packet.has_heartbeat():
		Signals.heartbeat_received.emit()
	elif packet.has_client_entered(): # CAUTION not doing anything yet
		_handle_client_entered_packet(packet.get_client_entered().get_nickname())
	elif packet.has_request_denied(): # CAUTION not doing anything yet
		_handle_request_denied_packet(packet.get_request_denied().get_reason())
	# PACKETS THAT USE SENDER_ID
	elif packet.has_public_message():
		_handle_public_message_packet(sender_id, packet.get_public_message())
	elif packet.has_chat_bubble():
		_handle_chat_bubble_packet(sender_id, packet.get_chat_bubble())
	elif packet.has_client_left():
		_handle_client_left_packet(sender_id, packet.get_client_left())
	elif packet.has_apply_player_damage():
		_handle_apply_player_damage_packet(sender_id, packet.get_apply_player_damage())


# Print the message into our chat window and update that player's chat bubble
func _handle_public_message_packet(sender_id: int, packet_public_message: Packets.PublicMessage) -> void:
	# We print the nickname and then the message contents in local chat
	chat.public("%s" % packet_public_message.get_nickname(), packet_public_message.get_text(), Color.LIGHT_SEA_GREEN)
	
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Update their chat bubble to reflect the text
		player.new_chat_bubble(packet_public_message.get_text())
		player.toggle_chat_bubble_icon(false) # Hide typing bubble


# We send a heartbeat packet to the server every time the timer timeouts
func _on_websocket_heartbeat_attempt() -> void:
	# We create a new packet of type heartbeat
	var packet := Packets.Packet.new()
	packet.new_heartbeat()
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	# If we sent the packet, emit it
	if !err:
		Signals.heartbeat_sent.emit()


# When a new client connects, we print the message into our chat window
func _handle_client_entered_packet(_nickname: String) -> void:
	# When a client connects, the server sends our data to him automatically
	pass


# When a client leaves, print the message into our chat window
# If that client was on our player list, we destroy his character to free resources
func _handle_client_left_packet(sender_id: int, client_left_packet: Packets.ClientLeft) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Remove this player from our grid
		RegionManager.remove_object(player.player_movement.server_grid_position, player)
		# Remove this player from our map of players
		GameManager.unregister_player(sender_id)
		# Destroy it
		player.queue_free()
	
	# Displays a message in the chat window
	chat.info("%s left" % client_left_packet.get_nickname())


# if our client presses the enter key in the chat
func _handle_signal_chat_public_message_sent(text: String) -> void:
	# Ignore this if the message was empty
	if text.is_empty():
		return
	
	# Create the public_message packet
	var packet := Packets.Packet.new()
	var public_message := packet.new_public_message()
	public_message.set_text(text)
	
	# Serialize and send our packet to the server
	var err := WebSocket.send(packet)
	if err:
		chat.error("You have been disconnected from the server")
	else:
		# Grab our client's nickname from the GameManager autoload
		# and display our own message in our client
		chat.public(GameManager.client_nickname, text, Color.CYAN)
		# Update my character's chat bubble!
		GameManager.player_character.new_chat_bubble(text)


# If the ui_escape key is pressed, toggle the escape menu
func _on_ui_escape_menu_toggle() -> void:
	# If we had our controls menu open, close it
	if game_controls_menu.is_active:
		game_controls_menu.toggle()
		return
	
	# Toggle our game escape menu
	game_escape_menu.toggle()


# If the F1 key is pressed, toggle the controls menu
func _handle_signal_ui_controls_menu_toggle() -> void:
	game_controls_menu.toggle()


# Used to request the server to switch us to the authentication state
func _handle_signal_ui_logout() -> void:
	# We create a new packet of type logout request
	var packet := Packets.Packet.new()
	packet.new_logout_request()
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	# If we sent the packet, emit it
	if !err:
		Signals.heartbeat_sent.emit()
		# Switch our local state to the authentication too
		GameManager.set_state(GameManager.State.AUTHENTICATION)


func _send_client_entered_packet() -> bool:
	# We create a new packet
	var packet := Packets.Packet.new()
	# We send the packet with no data because the server will fill it up
	packet.new_client_entered()
	
	# Serialize and send our message
	var err := WebSocket.send(packet)
	# Report if we succeeded or failed
	if err:
		return false
	else:
		return true


func _handle_request_denied_packet(reason: String) -> void:
	# Just jog the error to console for now
	print(reason)
	
	# TO UPGRADE
	# We need to have a Callable that we assign a different function
	# everytime we want to request something to the server so we don't
	# have a packet type for every type of request unless we have to!


func _handle_spawn_character_packet(spawn_character_packet: Packets.SpawnCharacter) -> void:
	var player_id := spawn_character_packet.get_id()
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(player_id)
	# If this player is NOT in our list of players
	# then is a new player so we need to spawn it
	if not player:
		# Check if our client id is the same as this update player packet sender id
		var is_my_player_character := player_id == GameManager.client_id
		
		# Get the spawn position from the packet
		var spawn_position: Vector2i = Vector2i(spawn_character_packet.get_position().get_x(), spawn_character_packet.get_position().get_z())
		var weapon_slots: Array[Dictionary] = []
		# Get the spawn weapons from the packet
		var spawn_weapons = spawn_character_packet.get_weapons()
		# Extract weapon slots from the packet
		for i in range(spawn_weapons.size()):
			var weapon_slot = spawn_weapons[i]
			weapon_slots.insert(weapon_slot.get_slot_index(), {
				"weapon_name": weapon_slot.get_weapon_name(),
				"weapon_type": weapon_slot.get_weapon_type(),
				"display_name": weapon_slot.get_display_name(),
				"ammo": weapon_slot.get_ammo(),
				"fire_mode": weapon_slot.get_fire_mode()
			})
		
		# Grab all of the data from the server and use it to create this player character
		var new_player: Player = Player.instantiate(
			player_id,
			spawn_character_packet.get_name(),
			spawn_character_packet.get_gender(),
			spawn_character_packet.get_speed(),
			spawn_position,
			spawn_character_packet.get_rotation_y(),
			is_my_player_character,
			spawn_character_packet.get_current_weapon(),
			weapon_slots
		)
		# Add this player to our map of players
		GameManager.register_player(player_id, new_player)
		
		# For remote players
		if not is_my_player_character:
			# Add the player to the new position in my local grid
			RegionManager.set_object(spawn_position, new_player)
		
		# Spawn the player
		_current_map_scene.add_child(new_player)


func _handle_region_data_packet(region_data_packet: Packets.RegionData) -> void:
	var region_id: int = region_data_packet.get_region_id()
	
	if region_id in RegionManager.Maps.values():
		# Initialize region first
		RegionManager.update_region_data(
			region_id,
			region_data_packet.get_grid_width(),
			region_data_packet.get_grid_height()
		)
		
		# Wait for map load before sending notifications
		await _load_map(region_id as RegionManager.Maps)
		
		# Send a packet to the server to let everyone know we joined,
		# after full initialization
		_send_client_entered_packet()
		
	else:
		# If the region id is invalid, load the prototype map
		_load_map(RegionManager.Maps.PROTOTYPE)
		# CAUTION Replace this with a request to the server to switch us to another map


# Used to switch regions/maps
func _load_map(map: RegionManager.Maps) -> void:
	# Clear previous map and players
	if _current_map_scene:
		_current_map_scene.queue_free()
		# Wait a frame to ensure cleanup
		await get_tree().process_frame
		# Clear and free each player we had including our own
		GameManager.clear_players()
	
	# Load new map
	var map_scene: PackedScene = load(RegionManager.maps_scenes[map])
	if map_scene:
		# Create the map scene
		_current_map_scene = map_scene.instantiate()
		# Add it to the game root
		add_child(_current_map_scene)


# Used to toggle the chat bubble of this character
func _handle_chat_bubble_packet(sender_id: int, chat_bubble_packet: Packets.ChatBubble) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Toggle the chat bubble for this player
		player.toggle_chat_bubble_icon(chat_bubble_packet.get_is_active())


func _route_move_character_packet(sender_id: int, move_character_packet: Packets.MoveCharacter) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(move_character_packet, PlayerPackets.Priority.NORMAL)


func _route_update_speed_packet(sender_id: int, update_speed_packet: Packets.UpdateSpeed) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(update_speed_packet, PlayerPackets.Priority.NORMAL)


# Used to switch the weapon of this character
func _route_switch_weapon_packet(sender_id: int, switch_weapon_packet: Packets.SwitchWeapon) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(switch_weapon_packet, PlayerPackets.Priority.NORMAL)


func _route_reload_weapon_packet(sender_id: int, reload_weapon_packet: Packets.ReloadWeapon) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(reload_weapon_packet, PlayerPackets.Priority.NORMAL)


func _route_raise_weapon_packet(sender_id: int, raise_weapon_packet: Packets.RaiseWeapon) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(raise_weapon_packet, PlayerPackets.Priority.NORMAL)


func _route_lower_weapon_packet(sender_id: int, lower_weapon_packet: Packets.LowerWeapon) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(lower_weapon_packet, PlayerPackets.Priority.NORMAL)


func _route_rotate_character_packet(sender_id: int, rotate_character_packet: Packets.RotateCharacter) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(rotate_character_packet, PlayerPackets.Priority.NORMAL)


func _route_fire_weapon_packet(sender_id: int, fire_weapon_packet: Packets.FireWeapon) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(fire_weapon_packet, PlayerPackets.Priority.NORMAL)


func _route_toggle_fire_mode_packet(sender_id: int, toggle_fire_mode_packet: Packets.ToggleFireMode) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(toggle_fire_mode_packet, PlayerPackets.Priority.NORMAL)


func _route_start_firing_weapon_packet(sender_id: int, start_firing_weapon_packet: Packets.StartFiringWeapon) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(start_firing_weapon_packet, PlayerPackets.Priority.NORMAL)


func _route_stop_firing_weapon_packet(sender_id: int, stop_firing_weapon_packet: Packets.StopFiringWeapon) -> void:
	# Attempt to retrieve the player character object
	var player: Player = GameManager.get_player_by_id(sender_id)
	if player:
		# Send this packet to the queue of this player
		player.player_packets.add_packet(stop_firing_weapon_packet, PlayerPackets.Priority.NORMAL)


func _handle_apply_player_damage_packet(sender_id: int, apply_damage_packet: Packets.ApplyPlayerDamage) -> void:
	var attacker_id: int = apply_damage_packet.get_attacker_id()
	if sender_id != attacker_id:
		push_error("sender_id is different from attacker_id in apply_player_damage_packet")
		return
	
	var target_id: int = apply_damage_packet.get_target_id()
	if not GameManager.is_player_valid(target_id):
		push_error("target_id is not in our map of connected players in apply_player_damage_packet")
		return
	
	# Get the rest of the data from the packet
	var damage: int = apply_damage_packet.get_damage()
	# var damage_type: String = apply_damage_packet.get_damage_type()
	var damage_position: Vector3 = Vector3(apply_damage_packet.get_x(), apply_damage_packet.get_y(), apply_damage_packet.get_z())
	
	SfxManager.spawn_damage_number(damage, damage_position)
	
	# NOTE Reduce health and stuff here
