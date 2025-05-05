class_name PlayerCamera
extends Camera3D

# Zoom settings
@export var min_distance: float = 4.0 # Closest distance (zoomed in)
@export var max_distance: float = 10.0 # Farthest distance (zoomed out)
@export var zoom_step: float = 1.0 # Distance per zoom action
@export var zoom_speed: float = 6.0 # Smoothing speed

var target_distance: float = 6.0 # Initial zoom
var zoom_direction: int = 0 # Direction we want to zoom (-1 or 1)

@onready var camera_rig: Node3D = get_parent()
@onready var base_direction: Vector3 = camera_rig.position.normalized()


func _ready() -> void:
	# Connect the signals
	Signals.ui_zoom_in.connect(_handle_signal_ui_zoom_in)
	Signals.ui_zoom_out.connect(_handle_signal_ui_zoom_out)
	
	# Initialize zoom
	target_distance = camera_rig.position.length()


func _process(delta) -> void:
	if zoom_direction != 0:
		# Apply zoom based on current direction
		target_distance += zoom_direction * zoom_step
		target_distance = clamp(target_distance, min_distance, max_distance)
		zoom_direction = 0
		
	# Interpolate the distance while maintaining direction
	var current_distance = camera_rig.position.length()
	var new_distance = lerp(current_distance, target_distance, zoom_speed * delta)
	camera_rig.position = base_direction * new_distance


func _handle_signal_ui_zoom_in() -> void:
	zoom_direction = -1 # Negative for zooming in (closer)


func _handle_signal_ui_zoom_out() -> void:
	zoom_direction = 1 # Positive for zooming out (farther)
