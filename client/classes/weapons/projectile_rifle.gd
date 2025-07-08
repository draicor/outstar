extends Node3D
class_name ProjectileRifle

@export var weapon_debug: bool = false
@export var weapon_max_distance: float = 50.0
@export var weapon_debug_duration: float = 0.2
@export var horizontal_recoil: float = 1.2
@export var vertical_recoil: float = 1.1
@export var lower_vertical_recoil: float = 4.5

@onready var muzzle_marker_3d: Marker3D = $MuzzleMarker3D
@onready var projectile_muzzle_flash: Node3D = $MuzzleMarker3D/ProjectileMuzzleFlash

const BULLET_TRACER = preload("res://sfx/projectile/bullet_tracer.tscn")

# Recoil variables
var min_yaw_recoil: float
var max_yaw_recoil: float
var min_pitch_recoil: float
var max_pitch_recoil: float


func _ready() -> void:
	calculate_recoil()


# Calculate the recoil deviation angles,
# If the recoil stats change for any reason (crouching, status effects),
# Then we have to call this function again for it to take effect!
func calculate_recoil() -> void:
	min_yaw_recoil = -horizontal_recoil
	max_yaw_recoil = horizontal_recoil
	min_pitch_recoil = -vertical_recoil * lower_vertical_recoil
	max_pitch_recoil = vertical_recoil


func single_fire() -> Vector3:
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# Create horizontal direction (ignoring weapon's vertical angle)
	var horizontal_direction := -muzzle_marker_3d.global_transform.basis.z
	
	var direction: Vector3 = _apply_recoil(horizontal_direction)

	# Perform raycast
	var hit: Dictionary = weapon_raycast(muzzle_position, direction)
	var hit_position: Vector3 = hit.position if hit else muzzle_position + direction * weapon_max_distance
	
	# CAUTION
	# Check if we CAN fire first (have ammo, can_shoot is valid, etc)
	projectile_muzzle_flash.restart()
	# Add the bullet tracer
	var tracer := BULLET_TRACER.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.initialize(muzzle_position, hit_position)
	
	if weapon_debug:
		if hit:
			# Draw green line from weapon to hit point
			DebugDraw3D.draw_line(
				muzzle_position,
				hit_position,
				Color(0.0, 1.0, 0.0, 0.3), # GREEN
				weapon_debug_duration
			)
		else:
			# If we missed, draw red line
			DebugDraw3D.draw_line(
				muzzle_position,
				hit_position,
				Color(1.0, 0.0, 0.0, 0.3), # RED
				weapon_debug_duration
			)
	
	if hit:
		# Check what kind of target we hit
		_process_hit(hit)
	
	return hit_position # <-- CAUTION not being used yet


func weapon_raycast(origin: Vector3, direction: Vector3) -> Dictionary:
	var ray_query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * weapon_max_distance
	)
	ray_query.collision_mask = 3 # Mask 1+2
	
	return get_world_3d().direct_space_state.intersect_ray(ray_query)


# Adds random recoil deviation to the shot direction
func _apply_recoil(direction: Vector3) -> Vector3:
	# Flatten to horizontal plane and normalize
	direction.y = 0
	direction = direction.normalized()
	
	# Generate random angles
	var yaw_angle = deg_to_rad(randf_range(min_yaw_recoil, max_yaw_recoil))
	var pitch_angle = deg_to_rad(randf_range(min_pitch_recoil, max_pitch_recoil))
	
	# Apply yaw (horizontal deviation)
	direction = direction.rotated(Vector3.UP, yaw_angle)
	# Apply pitch (vertical deviation)
	var right = direction.cross(Vector3.UP).normalized()
	direction = direction.rotated(right, pitch_angle)
	
	return direction


# Handle SFXs and ¿maybe impact sounds here?
func _process_hit(hit: Dictionary) -> void:
	var collider = hit.get("collider")
	
	if collider and collider.is_in_group("flesh_material"):
		SfxManager.spawn_projectile_impact_flesh(hit.position, hit.normal)
	elif collider and collider.is_in_group("headshot_material"):
		SfxManager.spawn_projectile_impact_headshot(hit.position, hit.normal)
	elif collider and collider.is_in_group("concrete_material"):
		SfxManager.spawn_projectile_impact_decal(hit.position, hit.normal, collider, "concrete_material")
		SfxManager.spawn_projectile_impact_concrete(hit.position, hit.normal)
