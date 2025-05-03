extends Node

const packets := preload("res://packets.gd")

@onready var clients_online: Label = $UI/MarginContainer/VBoxContainer/ClientsOnline
@onready var username_input: LineEdit = $UI/MarginContainer/VBoxContainer/Username
@onready var password_input: LineEdit = $UI/MarginContainer/VBoxContainer/Password
@onready var nickname_input: LineEdit = $UI/MarginContainer/VBoxContainer/Nickname
@onready var status: Label = $UI/MarginContainer/VBoxContainer/Status
@onready var login_button: Button = $UI/MarginContainer/VBoxContainer/HBoxContainer/LoginButton
@onready var register_button: Button = $UI/MarginContainer/VBoxContainer/HBoxContainer/RegisterButton

func _ready() -> void:
	# Websocket signals
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)
	# Connect the username/password inputs to the login
	username_input.text_submitted.connect(_on_login_input_text_submitted)
	password_input.text_submitted.connect(_on_login_input_text_submitted)
	# Focus on the username field
	username_input.grab_focus()

func _on_websocket_connection_closed() -> void:
	_update_status("You have been disconnected from the server")

func _on_websocket_packet_received(packet: packets.Packet) -> void:	
	if packet.has_request_denied():
		_update_status(packet.get_request_denied().get_reason())
	elif packet.has_request_granted():
		_handle_request_granted_packet()
	elif packet.has_login_success():
		_handle_login_success(packet.get_login_success())
	elif packet.has_server_metrics():
		_handle_server_metrics(packet.get_server_metrics())

# We need to get the _text from the event but we ignore it because
# we only care about the event itself, not the text being sent by it
func _on_login_input_text_submitted(_text: String) -> void:
	_on_login_button_pressed()

func _on_login_button_pressed() -> void:
	# We validate username and password fields
	# before we even try to talk to the server
	if not _name_is_valid(username_input):
		return
	if not _password_is_valid(password_input):
		return
	
	# Create the login_request packet
	var packet := packets.Packet.new()
	var login_request := packet.new_login_request()
	# Add the user input to the packet
	login_request.set_username(username_input.text)
	login_request.set_password(password_input.text)
	# Serialize and send it to the server
	var err := WebSocket.send(packet)
	if err:
		_update_status("Error connecting to the server")
	else:
		_update_status("Logging in...")

func _handle_login_success(login_success_packet: packets.LoginSuccess) -> void:
	# We store the info of our client sent by the server
	GameManager.client_nickname = login_success_packet.get_nickname()
	# Emit this signal to start the heartbeat timer in our WebSocket class
	Signals.login_success.emit()
	# Move this player to the GAME state
	GameManager.set_state(GameManager.State.GAME)

func _handle_server_metrics(server_metrics_packet: packets.ServerMetrics) -> void:
	var metrics_players_online := server_metrics_packet.get_players_online()
	clients_online.text = "Clients online: " + str(metrics_players_online)

func _on_register_button_pressed() -> void:
	# We validate all fields before we even try to talk to the server
	if not _name_is_valid(username_input):
		return
	if not _name_is_valid(nickname_input):
		return
	if not _password_is_valid(password_input):
		return
		
	# Create the register_request packet
	var packet := packets.Packet.new()
	var register_request := packet.new_register_request()
	# Add the user input to the packet
	register_request.set_username(username_input.text)
	register_request.set_nickname(nickname_input.text)
	register_request.set_password(password_input.text)
	# Serialize and send it to the server
	var err := WebSocket.send(packet)
	if err:
		_update_status("Error connecting to the server")
	else:
		_update_status("Creating user...")

func _handle_request_granted_packet() -> void:
	_update_status("Registration successful")

func _name_is_valid(input: LineEdit) -> bool:
	if input.text.is_empty():
		_update_status(input.name + " can't be empty")
		input.grab_focus()
		return false
	if input.text.length() > input.max_length:
		_update_status(input.name + " is too long")
		input.grab_focus()
		return false
	
	return true

func _password_is_valid(input: LineEdit) -> bool:
	if input.text.is_empty():
		_update_status(input.name + " can't be empty")
		input.grab_focus()
		return false
	if input.text.length() < 8:
		_update_status(input.name + " is too short")
		input.grab_focus()
		return false
	if input.text.length() > input.max_length:
		_update_status(input.name + " is too long")
		input.grab_focus()
		return false
	
	return true

func _update_status(text: String) -> void:
	status.text = text
