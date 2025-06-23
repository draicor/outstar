extends Node3D
class_name ProjectileRifle

@export var weapon_max_distance: float = 50.0
@onready var muzzle_marker_3d: Marker3D = $MuzzleMarker3D


func single_fire() -> Vector3:
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# Create horizontal direction (ignoring weapon's vertical angle)
	var horizontal_direction := -muzzle_marker_3d.global_transform.basis.z
	horizontal_direction.y = 0 # Flatten to horizontal plane
	horizontal_direction = horizontal_direction.normalized()

	# Perform raycast
	var hit_position: Vector3 = weapon_raycast(muzzle_position, horizontal_direction)
	
	if hit_position != Vector3.ZERO:
		# Draw debug line from weapon to hit point
		DebugDraw3D.draw_line(
			muzzle_position,
			hit_position,
			Color.YELLOW_GREEN, # Solid color
			0.5 # Duration in seconds
		)
	return hit_position

func weapon_raycast(origin: Vector3, direction: Vector3) -> Vector3:
	var ray_query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * weapon_max_distance
	)
	ray_query.collision_mask = 3 # Mask 1+2
	
	var hit = get_world_3d().direct_space_state.intersect_ray(ray_query)
	return hit.position if hit else origin + direction * weapon_max_distance
