extends Node

@onready var status: Label = $UI/Status

const LOADING_TIMEOUT: float = 0.5
const MAX_ATTEMPTS: int = 6 # 6 * 0.5 = 3s max wait time

var renderer: String = ""
var driver_specified: bool = false


func _ready() -> void:
	# Get the command-line arguments directly from OS
	var cmd_args = OS.get_cmdline_args()
	# Parse the arguments
	var requested_driver = parse_arguments(cmd_args)
	# Update our message
	update_status("Loading " + requested_driver + " rendering driver.")
	await get_tree().create_timer(LOADING_TIMEOUT).timeout
	
	# Wait for render initialization
	var timeout_count = 0
	var render_device_ready: bool = false
	# Loop until rendering device has loaded or timeouts
	while timeout_count < MAX_ATTEMPTS:
		if RenderingServer.get_rendering_device() != null:
			render_device_ready = true
			break
		
		await get_tree().create_timer(LOADING_TIMEOUT).timeout
		timeout_count += 1
	
	if render_device_ready:
		var selected_driver = RenderingServer.get_current_rendering_driver_name()
		if selected_driver:
			# Update our message
			update_status("Initializing " + selected_driver + " rendering driver.")
			await get_tree().create_timer(LOADING_TIMEOUT).timeout
			start_game()
		else:
			# Fatal graphic driver error
			show_dialog_error("Failed to initialize graphics rendering API.", "Graphics System Error")
			update_status("Failed to meet minimum system specifications.")
	else:
		handle_renderer_failure(requested_driver)


func parse_arguments(cmd_args: PackedStringArray) -> String:
	# Combine arguments into a single string with spaces for easier pattern matching
	var arg_string = " " + " ".join(cmd_args) + " "
	
	# Check all possible renderer argument patterns
	var renderers = {
		"opengl3": [
			" --rendering-driver opengl3 ",
			" --rendering-driver=opengl3 ",
			" -rd opengl3 ",
		],
		"opengl3_angle": [
			" --rendering-driver opengl3_angle ",
			" --rendering-driver=opengl3_angle ",
			" -rd opengl3_angle ",
			" --rendering-driver angle ",
			" --rendering-driver=angle ",
			" -rd angle ",
		],
		"opengl3_es": [
			" --rendering-driver opengl3_es ",
			" --rendering-driver=opengl3_es ",
			" -rd opengl3_es ",
			" --rendering-driver gles3 ",
			" --rendering-driver=gles3 ",
			" -rd gles3 ",
			" --rendering-driver es ",
			" --rendering-driver=es ",
			" -rd es ",
		],
	}
	
	# Check each renderer type
	for renderer in renderers:
		for pattern in renderers[renderer]:
			if pattern in arg_string:
				driver_specified = true
				return renderer
	
	return "vulkan" # Default to vulkan


func update_status(message: String) -> void:
	status.text = message


func handle_renderer_failure(requested_driver: String) -> void:
	var error_message: String
	
	if driver_specified:
		# User explicitly requested a renderer that failed
		error_message = "Failed to initialize %s renderer." % requested_driver
	else:
		# Default Vulkan renderer failed
		error_message = "Vulkan renderer failed to initialize."
	
	var help_message: String = (
		"Your hardware may not support this renderer.\n" +
		"Try changing the renderer to:\n" +
		"-rd vulkan\n" +
		"-rd opengl3\n" +
		"-rd opengl3_es\n" +
		"-rd opengl3_angle\n" +
		"Create a shortcut and add the argument after the executable path."
	)
	
	update_status(error_message)
	show_dialog_error(help_message, "Graphics System Error")


# CAUTION
func start_game() -> void:
	# This should be replaced with the main menu state scene
	# Transition into the Connected scene to connect to the server
	GameManager.set_state(GameManager.State.CONNECTED)


# Updates the game window message and shows an OS-native error dialog
func show_dialog_error(message, title) -> void:
	OS.alert(message, title)
