class_name PlayerCamera
extends Camera3D

# Camera settings
@export var CAMERA_NEAR_PLANE: float = 0.1
@export var CAMERA_FAR_PLANE: float = 100
# Zoom settings
@export var MIN_DISTANCE: float = 4.0 # Closest distance (zoomed in)
@export var MAX_DISTANCE: float = 10.0 # Farthest distance (zoomed out)
@export var ZOOM_STEP: float = 1.0 # Distance per zoom action
@export var ZOOM_SPEED: float = 6.0 # Smoothing speed
# Rotation settings
@export var ROTATION_SPEED: float = 5.0
@export var ROTATION_STEP: float = 45.0

# Zoom internal variables
var target_zoom_distance: float = 6.0 # Initial zoom
var zoom_direction: int = 0 # Direction we want to zoom (-1 zooms in, 1 zooms out)
var last_position: Vector3 # Keep track of last camera position to detect changes
# Rotation internal variables
var target_rotation: float = 0.0
var current_rotation: float = 0.0
var rotation_direction: int = 0 # Direction we want to zoom ()

@onready var camera_rig: Node3D = get_parent()
@onready var camera_pivot: Node3D = camera_rig.get_parent()
@onready var base_direction: Vector3 = camera_rig.position.normalized()


func _ready() -> void:
	# Connect the signals
	Signals.ui_zoom_in.connect(_handle_signal_ui_zoom_in)
	Signals.ui_zoom_out.connect(_handle_signal_ui_zoom_out)
	Signals.ui_rotate_camera_left.connect(_handle_signal_ui_rotate_camera_left)
	Signals.ui_rotate_camera_right.connect(_handle_signal_ui_rotate_camera_right)
	
	# Initialize zoom
	target_zoom_distance = camera_rig.position.length()
	last_position = camera_rig.position
	
	# Initialize rotation
	target_rotation = camera_pivot.rotation.y
	current_rotation = target_rotation
	
	# Setup camera
	self.near = CAMERA_NEAR_PLANE
	self.far = CAMERA_FAR_PLANE


# We keep the camera logic in _process because its smoother than _physics_process
func _process(delta) -> void:
	_update_zoom(delta)
	_update_rotation(delta)


# Handles camera zoom on tick
func _update_zoom(delta) -> void:
	var needs_update = false
	
	if zoom_direction != 0:
		# Apply zoom based on current direction
		var new_target = target_zoom_distance + (zoom_direction * ZOOM_STEP)
		new_target = clamp(new_target, MIN_DISTANCE, MAX_DISTANCE)
		
		if not is_equal_approx(new_target, target_zoom_distance):
			target_zoom_distance = new_target
			needs_update = true
		
		zoom_direction = 0
		
	# Only update if position changed
	var current_distance = camera_rig.position.length()
	if needs_update or not is_equal_approx(current_distance, target_zoom_distance):
		# Interpolate the distance while maintaining direction
		var new_distance = lerp(current_distance, target_zoom_distance, ZOOM_SPEED * delta)
		var new_position = base_direction * new_distance
		
		# Only set position if it actually changed
		if not new_position.is_equal_approx(last_position):
			camera_rig.position = new_position
			last_position = new_position


# Handles camera rotation on tick
func _update_rotation(delta) -> void:
	if rotation_direction != 0:
		# Snap target to nearest step before adding new rotation
		target_rotation = _snap_rotation_to_step(target_rotation, ROTATION_STEP)
		target_rotation += rotation_direction * ROTATION_STEP
		rotation_direction = 0
	
	# Smooth rotation interpolation
	if not is_equal_approx(current_rotation, target_rotation):
		current_rotation = lerp(
			current_rotation,
			target_rotation,
			ROTATION_SPEED * delta)
		
		# Snap to exact angle when close enough
		if abs(current_rotation - target_rotation) < 0.25:
			current_rotation = target_rotation
		
		camera_pivot.rotation.y = deg_to_rad(current_rotation)


# Helper function to snap angles to steps
func _snap_rotation_to_step(angle: float, step: float) -> float:
	return round(angle / step) * step


func _handle_signal_ui_zoom_in() -> void:
	zoom_direction = -1 # Negative for zooming in (closer)


func _handle_signal_ui_zoom_out() -> void:
	zoom_direction = 1 # Positive for zooming out (farther)


func _handle_signal_ui_rotate_camera_left() -> void:
	if not GameManager.is_player_typing:
		rotation_direction = 1 # Positive for left rotation


func _handle_signal_ui_rotate_camera_right() -> void:
	if not GameManager.is_player_typing:
		rotation_direction = -1 # Negative for right rotation 
