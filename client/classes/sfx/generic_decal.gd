extends Decal
class_name GenericDecal


const DECAL_LIFETIME = 30.0 # Seconds before removing itself

var cleanup_timer: Timer
var parent_mesh: Node3D # Reference to the mesh we are attached to


# Starts a timer to destroy this decal after some time, also rotates the decal randomly
func _ready() -> void:
	# Random size variation
	var size_factor =randf_range(0.8, 1.2)
	size = size * size_factor
	
	# Initialize cleanup timer
	cleanup_timer = Timer.new()
	cleanup_timer.wait_time = DECAL_LIFETIME
	cleanup_timer.timeout.connect(_on_timeout)
	add_child(cleanup_timer)
	cleanup_timer.start()


# Destroy after the timer ends
func _on_timeout() -> void:
	queue_free()


# Stores the parent mesh
func set_parent_mesh(mesh: Node3D) -> void:
	parent_mesh = mesh
