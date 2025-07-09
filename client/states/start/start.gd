extends Node

@onready var status: Label = $UI/Status


func _ready() -> void:
	# Check if we should force OpenGL from previous session
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		if config.get_value("graphics", "renderer", "") == "opengl3":
			# Already set to OpenGL, restart immediately
			restart_with_opengl()
			return
	
	# Wait for renderer initialization
	await get_tree().create_timer(1.0).timeout
	
	# Check if Vulkan failed to initialize
	if RenderingServer.get_rendering_device() == null:
		switch_to_opengl()
	else:
		# Vulkan is working, proceed to game
		start_game()


func start_game() -> void:
	status.text = "Starting game..."
	# Transition into the Connected scene to connect to the server
	GameManager.set_state(GameManager.State.CONNECTED)


func restart_with_opengl() -> void:
	var executable_path := OS.get_executable_path()
	var args := PackedStringArray(["--rendering-driver", "opengl3"])
	var error := OS.execute(executable_path, args)
	
	if error != OK:
		show_fatal_error("Failed to start in OpenGL mode")
	
	# Close the first client leaving the second client open
	get_tree().quit()


func switch_to_opengl() -> void:
	status.text = "Vulkan failed, switching to OpenGL"
	
	# Save renderer preference for future launches on this computer
	save_renderer_setting("opengl3")
	restart_with_opengl()


func save_renderer_setting(renderer_name) -> void:
	var config: ConfigFile = ConfigFile.new()
	# Update settings.cfg with the renderer_name
	config.set_value("graphics", "renderer", renderer_name)
	# Save to user directory
	config.save("user://settings.cfg")
	
	print("Saved renderer settings: ", renderer_name)


func show_fatal_error(message) -> void:
	push_error(message)
	# Update the game window message
	status.text = message
	# Try to show OS-native error dialog
	OS.alert(message, "Fatal Graphics System Error")
