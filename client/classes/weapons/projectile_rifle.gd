extends Node3D
class_name ProjectileRifle

@export var weapon_max_distance: float = 50.0
@export var weapon_trail_duration: float = 0.2
@onready var muzzle_marker_3d: Marker3D = $MuzzleMarker3D
@onready var projectile_muzzle_flash: Node3D = $MuzzleMarker3D/ProjectileMuzzleFlash

const BULLET_TRACER = preload("res://sfx/projectile/bullet_tracer.tscn")


func single_fire() -> Vector3:
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# Create horizontal direction (ignoring weapon's vertical angle)
	var horizontal_direction := -muzzle_marker_3d.global_transform.basis.z
	horizontal_direction.y = 0 # Flatten to horizontal plane
	horizontal_direction = horizontal_direction.normalized()

	# Perform raycast
	var hit: Dictionary = weapon_raycast(muzzle_position, horizontal_direction)
	var hit_position: Vector3 = hit.position if hit else muzzle_position + horizontal_direction * weapon_max_distance
	
	# CAUTION check if we fired first (had ammo, can_shoot is valid, etc)
	projectile_muzzle_flash.restart()
	# Add the bullet tracer
	var tracer := BULLET_TRACER.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.initialize(muzzle_position, hit_position)
	
	# Draw debug line from weapon to hit point
	if hit:
		#DebugDraw3D.draw_line(
			#muzzle_position,
			#hit_position,
			#Color(0.0, 1.0, 0.0, 0.3), # GREEN
			#weapon_trail_duration
		#)
		# Check what kind of target we hit
		_process_hit(hit)
	
	# If we missed, draw a different line here
	#else:
		#DebugDraw3D.draw_line(
			#muzzle_position,
			#hit_position,
			#Color(1.0, 0.0, 0.0, 0.3), # RED
			#weapon_trail_duration
		#)
	
	return hit_position # <-- CAUTION not being used yet


func weapon_raycast(origin: Vector3, direction: Vector3) -> Dictionary:
	var ray_query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * weapon_max_distance
	)
	ray_query.collision_mask = 3 # Mask 1+2
	
	return get_world_3d().direct_space_state.intersect_ray(ray_query)


# Handle SFXs and maybe sounds here too?
func _process_hit(hit: Dictionary) -> void:
	var collider = hit.get("collider")
	if collider and collider.is_in_group("flesh_material"):
		SfxManager.spawn_projectile_impact_flesh(hit.position, hit.normal)
	elif collider and collider.is_in_group("concrete_material"):
		SfxManager.spawn_projectile_impact_decal(hit.position, hit.normal, collider, "concrete_material")
		SfxManager.spawn_projectile_impact_concrete(hit.position, hit.normal)
