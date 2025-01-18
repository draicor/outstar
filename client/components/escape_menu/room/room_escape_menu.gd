extends Control

@onready var version: Label = $VBoxContainer/Version
@onready var latency: Label = $VBoxContainer/Latency

var is_active : bool = false
var ping : int = 0

# Start hidden
func _init() -> void:
	self.hide()

func _ready() -> void:
	# Connect the heartbeat signals
	Signals.heartbeat_sent.connect(_on_heartbeat_sent)
	Signals.heartbeat_received.connect(_on_heartbeat_received)
	
	# Get the version of the project and display it
	version.text = "v" + ProjectSettings.get_setting("application/config/version")

func _on_heartbeat_sent() -> void:
	ping = Time.get_ticks_msec()

func _on_heartbeat_received() -> void:
	ping = Time.get_ticks_msec() - ping
	latency.text = str(ping) + "ms"

# Input Signals
func _on_resume_pressed() -> void:
	toggle()

# Emit the leave room signal
func _on_leave_room_pressed() -> void:
	Signals.ui_leave_room.emit()

func _on_quit_pressed() -> void:
	# Replace this with a better safer way to quit
	get_tree().quit()

# Used to show/hide this menu
func toggle() -> void:
	if is_active:
		self.hide()
		is_active = false
	else:
		self.show()
		is_active = true
