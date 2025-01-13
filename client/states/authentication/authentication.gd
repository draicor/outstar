extends Node

const packets := preload("res://packets.gd")

@onready var username: LineEdit = $UI/MarginContainer/VBoxContainer/Username
@onready var password: LineEdit = $UI/MarginContainer/VBoxContainer/Password
@onready var nickname: LineEdit = $UI/MarginContainer/VBoxContainer/Nickname
@onready var status: Label = $UI/MarginContainer/VBoxContainer/Status
@onready var login_button: Button = $UI/MarginContainer/VBoxContainer/HBoxContainer/LoginButton
@onready var register_button: Button = $UI/MarginContainer/VBoxContainer/HBoxContainer/RegisterButton

func _ready() -> void:
	# Websocket signals
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)

func _on_websocket_connection_closed() -> void:
	_update_status("You have been disconnected from the server")

func _on_websocket_packet_received(packet: packets.Packet) -> void:	
	if packet.has_request_denied():
		_update_status(packet.get_request_denied().get_reason())
	elif packet.has_request_granted():
		_handle_request_granted_packet()
	elif packet.has_login_success():
		_handle_login_success(packet.get_login_success())


func _on_login_button_pressed() -> void:
	# Create the login_request packet
	var packet := packets.Packet.new()
	var login_request := packet.new_login_request()
	# Add the user input to the packet
	login_request.set_username(username.text)
	login_request.set_password(password.text)
	# Serialize and send it to the server
	var err := WebSocket.send(packet)
	if err:
		_update_status("Error connecting to the server")
	else:
		_update_status("Logging in...")

func _handle_login_success(login_success_packet: packets.LoginSuccess) -> void:
	# We store the info of our client sent by the server
	GameManager.client_nickname = login_success_packet.get_nickname()
	GameManager.set_state(GameManager.State.LOBBY)

func _on_register_button_pressed() -> void:
	# Create the register_request packet
	var packet := packets.Packet.new()
	var register_request := packet.new_register_request()
	# Add the user input to the packet
	register_request.set_username(username.text)
	register_request.set_nickname(nickname.text)
	register_request.set_password(password.text)
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
		_update_status(input.name + "is too short")
		input.grab_focus()
		return false
	if input.text.length() > input.max_length:
		_update_status(input.name + " is too long")
		input.grab_focus()
		return false
	
	return true

func _update_status(text: String) -> void:
	status.text = text
