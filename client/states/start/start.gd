extends Node

@onready var status: Label = $UI/Status


func _ready() -> void:
	start_game()


func start_game() -> void:
	# This should be replaced with the main menu state scene
	# Transition into the Connected scene to connect to the server
	GameManager.set_state(GameManager.State.CONNECTED)


func update_status(message: String) -> void:
	status.text = message


# DEPRECATED
# Kept here in case I want to parse arguments in the future for game stuff
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
				return renderer
	
	return "vulkan" # Default to vulkan
