class_name Log
extends RichTextLabel

# Internal function to add a text to the log with a color
func _message(message: String, color: Color = Color.WHITE) -> void:
	append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), str(message)])

func info(message: String) -> void:
	_message(message, Color.LIGHT_SEA_GREEN)

func warning(message: String) -> void:
	_message(message, Color.YELLOW)

func error(message: String) -> void:
	_message(message, Color.ORANGE_RED)

func success(message: String) -> void:
	_message(message, Color.LAWN_GREEN)

# Formats the message to display sender: message
func public_chat(sender_name: String, message: String) -> void:
	_message("[color=#%s]%s:[/color] [i]%s[/i]" % [Color.CYAN.to_html(false), sender_name, message])
