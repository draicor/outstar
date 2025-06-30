extends Decal

const DECAL_LIFETIME = 20.0 # Seconds before removing itself

var cleanup_timer: Timer


func _ready() -> void:
	# Initialize cleanup timer
	cleanup_timer = Timer.new()
	cleanup_timer.wait_time = DECAL_LIFETIME
	cleanup_timer.timeout.connect(queue_free)
	add_child(cleanup_timer)
	cleanup_timer.start()
	
	# Apply random rotation when spawned
	rotate_object_local(Vector3(0, 1, 0), randf_range(0, TAU))
