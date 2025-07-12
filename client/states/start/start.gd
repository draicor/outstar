extends Node

@onready var status: Label = $UI/Status


func _ready() -> void:
	
	# Wait for renderer initialization
	await get_tree().create_timer(0.5).timeout
	
	# Check if Vulkan failed to initialize
	if RenderingServer.get_rendering_device() == null:
		show_fatal_error("Vulkan graphics failure, please run the game in compatibility mode.")
	else:
		# Vulkan API is working, proceed to game
		start_game()


func start_game() -> void:
	status.text = "Starting game..."
	await get_tree().create_timer(0.1).timeout
	
	# CAUTION
	# This should be replaced with the main menu state scene
	# Transition into the Connected scene to connect to the server
	GameManager.set_state(GameManager.State.CONNECTED)


func show_fatal_error(message) -> void:
	push_error(message)
	# Update the game window message
	status.text = message
	# Try to show OS-native error dialog
	OS.alert(message, "Fatal Graphics System Error")
