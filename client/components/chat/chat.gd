extends Control

@export var MESSAGE_MARGIN_LEFT: int = 5

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer


func info(message: String) -> void:
	_instantiate_message().info(message)

func warning(message: String) -> void:
	_instantiate_message().warning(message)

func error(message: String) -> void:
	_instantiate_message().error(message)

func success(message: String) -> void:
	_instantiate_message().success(message)

func public(sender_name: String, message: String, color: Color) -> void:
	_instantiate_message().public(sender_name, message, color)

func _instantiate_message() -> Message:
	var m = Message.new()
	# We add a margin container and append it to every message object
	var margin = MarginContainer.new()
	margin.add_child(m, false)
	margin.add_theme_constant_override("margin_left", MESSAGE_MARGIN_LEFT)
	
	# We add it to the VBoxContainer with force readable name set to false
	v_box_container.add_child(margin, false)
	
	# If we are at the bottom of the chat window, we auto scroll down
	if _should_auto_scroll():
		_scroll_to_bottom()
	
	return m

func _should_auto_scroll() -> bool:
	# We subtract the height of the container from the scrolls bar height
	# and we compare it to the current vertical scroll, it has to be >=
	# because at first it will always return false, preventing it from
	# auto scrolling once the scroll bar appears.
	return scroll_container.scroll_vertical >= (scroll_container.get_v_scroll_bar().max_value - scroll_container.get_rect().size.y)

func _scroll_to_bottom() -> void:
	# Await here to give the engine time to catch up
	await scroll_container.get_v_scroll_bar().changed
	scroll_container.scroll_vertical =  int(scroll_container.get_v_scroll_bar().max_value)


# Signal connected on the editor
func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if event.is_action("zoom_in") or event.is_action("zoom_out"):
		# Blocks the zoom actions from propagating and
		# prevents scrolling the chat history, it has to be done manually
		# using the grabber
		accept_event()
