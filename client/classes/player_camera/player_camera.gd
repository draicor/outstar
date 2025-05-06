class_name PlayerCamera
extends Camera3D

# Zoom settings
@export var min_distance: float = 4.0 # Closest distance (zoomed in)
@export var max_distance: float = 10.0 # Farthest distance (zoomed out)
@export var zoom_step: float = 1.0 # Distance per zoom action
@export var zoom_speed: float = 6.0 # Smoothing speed

var target_distance: float = 6.0 # Initial zoom
var zoom_direction: int = 0 # Direction we want to zoom (-1 or 1)
var last_position: Vector3 # Keep track of last camera position to detect changes

@onready var camera_rig: Node3D = get_parent()
@onready var base_direction: Vector3 = camera_rig.position.normalized()


func _ready() -> void:
	# Connect the signals
	Signals.ui_zoom_in.connect(_handle_signal_ui_zoom_in)
	Signals.ui_zoom_out.connect(_handle_signal_ui_zoom_out)
	
	# Initialize zoom
	target_distance = camera_rig.position.length()
	last_position = camera_rig.position


# We keep the camera logic in _process because its smoother than _physics_process
func _process(delta) -> void:
	var needs_update = false
	
	if zoom_direction != 0:
		# Apply zoom based on current direction
		var new_target = target_distance + (zoom_direction * zoom_step)
		new_target = clamp(new_target, min_distance, max_distance)
		
		if not is_equal_approx(new_target, target_distance):
			target_distance = new_target
			needs_update = true
		
		zoom_direction = 0
		
	# Only update if position changed
	var current_distance = camera_rig.position.length()
	if needs_update or not is_equal_approx(current_distance, target_distance):
		# Interpolate the distance while maintaining direction
		var new_distance = lerp(current_distance, target_distance, zoom_speed * delta)
		var new_position = base_direction * new_distance
		
		# Only set position if it actually changed
		if not new_position.is_equal_approx(last_position):
			camera_rig.position = new_position
			last_position = new_position


func _handle_signal_ui_zoom_in() -> void:
	zoom_direction = -1 # Negative for zooming in (closer)


func _handle_signal_ui_zoom_out() -> void:
	zoom_direction = 1 # Positive for zooming out (farther)
