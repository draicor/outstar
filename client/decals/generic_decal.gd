extends Decal


func _ready() -> void:
	# Apply random rotation when spawned
	rotate_object_local(Vector3(0, 1, 0), randf_range(0, TAU))
