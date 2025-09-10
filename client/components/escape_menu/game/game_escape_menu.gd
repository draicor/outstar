extends Control

@onready var version: Label = $VBoxContainer/Version
@onready var latency: Label = $VBoxContainer/Latency
@onready var renderer: Label = $VBoxContainer/Renderer
# Packets
@onready var packets_lost: Label = $BottomRightContainer/PacketsContainer/PacketsLostContainer/PacketsLost
@onready var packets_sent: Label = $BottomRightContainer/PacketsContainer/PacketsSentContainer/PacketsSent
@onready var packets_received: Label = $BottomRightContainer/PacketsContainer/PacketsReceivedContainer/PacketsReceived

var is_active : bool = false
var ping : int = 0

# Start hidden
func _init() -> void:
	hide()


func _ready() -> void:
	# Connect the heartbeat signals
	Signals.heartbeat_sent.connect(_on_heartbeat_sent)
	Signals.heartbeat_received.connect(_on_heartbeat_received)
	
	# Get the graphics renderer
	renderer.text = RenderingServer.get_current_rendering_driver_name()
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


func _on_logout_pressed() -> void:
	Signals.ui_logout.emit()


func _on_quit_pressed() -> void:
	# Replace this with a better safer way to quit
	get_tree().quit()


# Used to show/hide this menu
func toggle() -> void:
	if is_active:
		hide()
		is_active = false
		GameManager.set_ui_menu_active(false)
	# Hide menu
	else:
		update_packets_counter()
		show()
		is_active = true
		GameManager.set_ui_menu_active(true)


func _on_controls_pressed() -> void:
	Signals.ui_controls_menu_toggle.emit()


func update_packets_counter() -> void:
	packets_lost.text = str(GameManager.packets_lost)
	packets_sent.text = str(GameManager.packets_sent)
	packets_received.text = str(GameManager.packets_received)
