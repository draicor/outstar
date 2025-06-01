class_name Message
extends RichTextLabel


func _init() -> void:
	# This makes this label visible inside a container
	set_fit_content(true)
	# Improves performance for many messages
	selection_enabled = false
	# Set mouse filter to ignore (pass through) mouse events,
	# to allow the player to click through the chat window
	mouse_filter = MOUSE_FILTER_IGNORE
	# Enable text wrapping
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_active = false


# Internal function to add a text to the log with a color
func _add_text(message: String, color: Color = Color.WHITE) -> void:
	# We use append_text because it parses BBcode
	append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), str(message)])


func info(message: String) -> void:
	_add_text(message, Color.LIGHT_SEA_GREEN)


func warning(message: String) -> void:
	_add_text(message, Color.YELLOW)


func error(message: String) -> void:
	_add_text(message, Color.ORANGE_RED)


func success(message: String) -> void:
	_add_text(message, Color.LAWN_GREEN)


# Formats the message to display sender: message
func public(sender_name: String, message: String, color: Color) -> void:
	_add_text("[color=#%s]%s[/color]: [i]%s[/i]" % [color.to_html(false), sender_name, message])
