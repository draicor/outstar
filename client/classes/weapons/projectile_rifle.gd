extends Node3D
class_name ProjectileRifle

# This is how we will spawn the correct weapon model
enum FireModes { SEMI, AUTO }
enum Rifles { M16, AKM }
var RifleType: Dictionary[Rifles, String] = {
	Rifles.M16: "m16_rifle",
	Rifles.AKM: "akm_rifle",
}
# Automatic rifle default stats
# M16 800 RPM -> 4.0 fire rate, 1.2 hrecoil, 1.3 vrecoil
# AKM 600 RPM -> 3.0 fire rate, 1.4 hrecoil, 1.7 vrecoil

@export var weapon_model: Rifles = Rifles.M16
# Debug
@export var debug: bool = false
@export var debug_duration: float = 0.2
# Weapon stats
@export var weapon_max_distance: float = 40.0 # meters

# Recoil stats
@export var automatic_mode_extra_recoil: float = 2.0
@export var horizontal_recoil: float = 1.0
@export var vertical_recoil: float = 1.0
@export var lower_vertical_recoil: float = 4.5
var min_yaw_recoil: float
var max_yaw_recoil: float
var min_pitch_recoil: float
var max_pitch_recoil: float

# References
@onready var muzzle_marker_3d: Marker3D = $MuzzleMarker3D
@onready var projectile_muzzle_flash: Node3D = $MuzzleMarker3D/ProjectileMuzzleFlash

# Preload scenes
const BULLET_TRACER = preload("res://sfx/projectile/bullet_tracer.tscn")

# Target variables
var target_direction: Vector3

# Fire rate mode system
var fire_rates: Dictionary = {}
@export var has_multiple_modes: bool = true
@export var semi_fire_rate: float = 1.0
@export var auto_fire_rate: float = 3.0 # 0.1 seconds per shot, 600 RPM
var current_fire_mode: FireModes = FireModes.SEMI


func _ready() -> void:
	calculate_recoil()
	_initialize_fire_rates()


# Calculate the recoil deviation angles,
# If the recoil stats change for any reason (crouching, status effects),
# Then we have to call this function again for it to take effect!
func calculate_recoil() -> void:
	min_yaw_recoil = -horizontal_recoil
	max_yaw_recoil = horizontal_recoil
	min_pitch_recoil = -lower_vertical_recoil
	max_pitch_recoil = vertical_recoil
	
	# If using automatic mode
	if current_fire_mode == FireModes.AUTO:
		# Double the vertical recoil
		max_pitch_recoil *= automatic_mode_extra_recoil
		# Slightly increase the horizontal recoil
		min_yaw_recoil *= 1.1
		max_yaw_recoil *= 1.1


# Sets the dictionary variables that will control the attack speed of this weapon
func _initialize_fire_rates() -> void:
	fire_rates = {
		FireModes.SEMI: {
			"animation": "rifle/rifle_aim_fire_single_fast",
			"play_rate": semi_fire_rate
		},
		FireModes.AUTO: {
			"animation": "rifle/rifle_aim_fire_single_fast",
			"play_rate": auto_fire_rate
		}
	}


func fire(direction: Vector3 = Vector3.ZERO) -> Vector3:
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# If we forgot to set this, at least it will fire in the same direction
	if direction == Vector3.ZERO:
		# Create horizontal direction (ignoring weapon's vertical angle)
		target_direction = -muzzle_marker_3d.global_transform.basis.z
		
	var target: Vector3 = _apply_recoil(target_direction)

	# Perform raycast
	var hit: Dictionary = weapon_raycast(muzzle_position, target)
	var hit_position: Vector3 = hit.position if hit else muzzle_position + target * weapon_max_distance
	
	# We already checked if we can fire in player_equipment.weapon_fire()
	projectile_muzzle_flash.restart()
	# Add the bullet tracer
	var tracer := BULLET_TRACER.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.initialize(muzzle_position, hit_position)
	
	if debug:
		var debug_color = Color.GREEN if hit else Color.RED
		DebugDraw3D.draw_line(muzzle_position, hit_position, debug_color, debug_duration)
	
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
	ray_query.hit_from_inside = true
	ray_query.exclude = [] # Nothing gets excluded
	
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = true
	
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


# If this weapon has multiple fire modes, then cycle between them
# It always starts in the semi automatic mode, which is the default of all firearms
func toggle_fire_mode() -> void:
	if has_multiple_modes:
		current_fire_mode = (current_fire_mode + 1) % FireModes.size() as FireModes
		calculate_recoil()


func set_fire_mode(mode: int) -> void:
	current_fire_mode = mode as FireModes
	calculate_recoil()


func get_animation() -> String:
	return fire_rates[current_fire_mode]["animation"]


func get_animation_play_rate() -> float:
	return fire_rates[current_fire_mode]["play_rate"]


# Handle SFXs and Impact sounds here
func _process_hit(hit: Dictionary) -> void:
	var collider = hit.get("collider")
	
	if collider and collider.is_in_group("body_material"):
		SfxManager.spawn_projectile_impact_body(hit.position, hit.normal)
		AudioManager.play_bullet_impact_body(hit.position)
		
	elif collider and collider.is_in_group("headshot_material"):
		SfxManager.spawn_projectile_impact_headshot(hit.position, hit.normal)
		AudioManager.play_bullet_impact_headshot(hit.position)
	elif collider and collider.is_in_group("concrete_material"):
		SfxManager.spawn_projectile_impact_decal(hit.position, hit.normal, collider, "concrete_material")
		SfxManager.spawn_projectile_impact_concrete(hit.position, hit.normal)
		AudioManager.play_bullet_impact_concrete(hit.position)
