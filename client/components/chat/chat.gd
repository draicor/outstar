extends Control

@export var MESSAGE_MARGIN_LEFT: int = 5
@export var SCROLLING_SPEED: float = 0.5

@onready var chat_container: VBoxContainer = $ChatContainer
@onready var chat_button_row: VBoxContainer = $ChatContainer/ChatButtonRow
@onready var history_check_button: CheckButton = $ChatContainer/ChatButtonRow/HistoryCheckButton
@onready var chat_history: PanelContainer = $ChatContainer/ChatHistory
@onready var scroll_container: ScrollContainer = $ChatContainer/ChatHistory/ScrollContainer
@onready var messages_container: VBoxContainer = $ChatContainer/ChatHistory/ScrollContainer/MessagesContainer
@onready var chat_input: LineEdit = $ChatContainer/ChatInput


func _ready() -> void:
	# Start with the whole chat hidden
	chat_container.visible = false
	# When the chat window opens, the chat history will be hidden by default
	chat_history.visible = false
	
	# Disable focus for the toggle button
	history_check_button.focus_mode = Control.FOCUS_NONE
	
	# Semi-transparent scrollbar
	scroll_container.get_v_scroll_bar().modulate.a = 0.7
	
	# Connect the UI and Chat signals
	Signals.ui_chat_input_toggle.connect(_on_ui_chat_input_toggle)
	chat_input.text_submitted.connect(_on_chat_input_text_submitted)


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
	
	# We add it to the MessagesContainer with force readable name set to false
	messages_container.add_child(margin, false)
	
	# Force layout update
	messages_container.queue_redraw()
	scroll_container.queue_redraw()
	
	if _should_auto_scroll():
		# Use call_deferred to handle scrolling after the frame
		call_deferred("_scroll_to_bottom")
	
	return m


func _should_auto_scroll() -> bool:
	var current_pos: int = scroll_container.scroll_vertical
	var content_height: float = messages_container.size.y
	var view_height: float = scroll_container.size.y
	
	# Consider us at bottom if within 20px of the end.
	# it has to be >= here because at first it will always return false, preventing it from
	# auto scrolling once the scroll bar appears.
	return current_pos >= (content_height - view_height - 20)


func _scroll_to_bottom() -> void:
	# Wait for proper layout calculations
	await get_tree().process_frame
	await get_tree().process_frame
	
	var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()
	if not scrollbar:
		return
	
	# Calculate the bottom position
	var content_height: float = messages_container.size.y
	var view_height: float = scroll_container.size.y
	var target_scroll: float = content_height - view_height
	
	# Ensure we don't scroll past content
	target_scroll = max(0, target_scroll)
	
	# Apply with smoothing
	var tween: Tween = create_tween()
	tween.tween_property(scroll_container, "scroll_vertical", target_scroll, SCROLLING_SPEED)


# Signal connected on the editor
func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if event.is_action("zoom_in") or event.is_action("zoom_out"):
		# Blocks the zoom actions from propagating and
		# prevents scrolling the chat history, it has to be done manually
		# using the grabber
		accept_event()


# Signal connected on the editor
func _on_history_check_button_toggled(toggled_on: bool) -> void:
	chat_history.visible = toggled_on
	if toggled_on:
		_scroll_to_bottom()


# If the ui_enter key is pressed, toggle the chat window and grab chat input focus
func _on_ui_chat_input_toggle() -> void:
	# Toggle the chat window
	chat_container.visible = !chat_container.visible
	# If the chat input line is visible, grab type focus
	if chat_input.visible:
		chat_input.grab_focus()
	
	# If our chat container is visible
	if chat_container.visible:
		# If we have our view history check active, scroll down automatically
		if history_check_button.button_pressed:
			_scroll_to_bottom()


# if our client presses the enter key in the chat
func _on_chat_input_text_submitted(text: String) -> void:
	# Remove leading/trailing whitespace
	var clean_text: String = text.strip_edges()
	# Ignore this if the message was empty and release focus!
	if clean_text.is_empty():
		chat_input.release_focus()
		return
	
	Signals.chat_public_message_sent.emit(clean_text)
	
	# We clear the line edit
	chat_input.text = ""
