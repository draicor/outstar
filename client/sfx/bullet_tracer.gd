extends Node3D

@export var max_distance: float = 50.0 # Should match the weapon's max distance
@export var lifetime: float = 0.08

@onready var mesh: MeshInstance3D = $MeshInstance3D


# Positions, rotates and scales the bullet tracer towards the target,
# Destroys it after the lifetime ends.
func initialize(start_position: Vector3, target_position: Vector3) -> void:
	global_position = start_position
	look_at(target_position)
	
	# Scale quad to match distance
	var distance: float = start_position.distance_to(target_position)
	mesh.scale.y = min(distance, max_distance)
	
	# Position center of quad at midpoint
	mesh.position.z = -mesh.scale.y / 2
	
	# Auto remove after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()
