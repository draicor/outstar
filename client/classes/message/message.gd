class_name Message
extends RichTextLabel

func _init() -> void:
	# This makes this label visible inside a container
	set_fit_content(true)

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
func public(sender_name: String, message: String) -> void:
	_add_text("[color=#%s]%s:[/color] [i]%s[/i]" % [Color.CYAN.to_html(false), sender_name, message])
