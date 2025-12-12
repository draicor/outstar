extends Node3D
class_name ProjectileWeapon

# Common weapon properties
enum FireModes { SEMI, AUTO }

# Debug
@export var debug: bool = false
@export var debug_duration: float = 0.2

# Weapon stats
@export var weapon_max_distance: float = 30.0 # meters

# Recoil stats
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
@export var has_multiple_modes: bool = false
@export var semi_fire_rate: float = 1.0
@export var auto_fire_rate: float = 1.0
var current_fire_mode: FireModes = FireModes.SEMI

# Fire rates dictionary - child classes should override _initialize_fire_rates()
var fire_rates: Dictionary = {}


func _ready() -> void:
	calculate_recoil()
	_initialize_fire_rates()


# Virtual function - child classes must override to set up their fire rates
func _initialize_fire_rates() -> void:
	# Default implementation - child classes should override
	fire_rates = {
		FireModes.SEMI: {
			"standing": { "play_rate": semi_fire_rate },
			"crouching": { "play_rate": semi_fire_rate }
		},
		FireModes.AUTO: {
			"standing": { "play_rate": auto_fire_rate },
			"crouching": { "play_rate": auto_fire_rate }
		}
	}


# Calculate the recoil deviation angles
func calculate_recoil() -> void:
	min_yaw_recoil = -horizontal_recoil
	max_yaw_recoil = horizontal_recoil
	min_pitch_recoil = -lower_vertical_recoil
	max_pitch_recoil = vertical_recoil
	
	# Child classes can override to add additional recoil calculations


# Adds multiple sphere shapes cast along the barrel to detect if the weapon is inside geometry
func is_weapon_inside_wall() -> bool:
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# Get the direction from muzzle back towards the weapon
	var backward_direction: Vector3 = muzzle_marker_3d.global_transform.basis.z
	
	# Check multiple points along the barrel
	var check_points: int = 4
	var barrel_length: float = 0.5
	
	for i in range(check_points):
		var check_distance: float = (barrel_length / (check_points - 1)) * i
		var check_position = muzzle_position + backward_direction * check_distance
		
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 0.04 # Small radius around muzzle
	
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = check_position
		query.collision_mask = 1 # Static layer
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = GameManager.get_exclude_collision_rids()
	
		var results: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query)
		
		# Debug visualization
		if debug:
			if DebugDraw3D:
				var color: Color = Color.RED if results.size() > 0 else Color.GREEN
				DebugDraw3D.draw_sphere(check_position, 0.04, color, 0.2)
		
		if results.size() > 0:
			return true
	
	# No collision
	return false


# Virtual function - child classes must override to calculate hit positions
func calculate_hit_positions(_direction: Vector3 = Vector3.ZERO) -> Array[Vector3]:
	push_error("calculate_hit_positions must be implemented in child class")
	return []


# Virtual function - child classes must override to implement firing
func fire(_hits: Array[Vector3]) -> void:
	push_error("fire must be implemented in child class")


# Common raycast function for all projectile weapons
func weapon_raycast(origin: Vector3, direction: Vector3) -> Dictionary:
	var ray_query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * weapon_max_distance
	)
	ray_query.collision_mask = 3 # Mask 1+2
	ray_query.hit_from_inside = true
	ray_query.exclude = GameManager.get_exclude_collision_rids()
	
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
func toggle_fire_mode() -> void:
	if has_multiple_modes:
		current_fire_mode = (current_fire_mode + 1) % FireModes.size() as FireModes
		calculate_recoil()


func set_fire_mode(mode: int) -> void:
	current_fire_mode = mode as FireModes
	calculate_recoil()


# Returns the appropriate animation play rate based on stance and fire mode
func get_animation_play_rate(stance: String) -> float:
	if fire_rates.has(current_fire_mode) and fire_rates[current_fire_mode].has(stance):
		return fire_rates[current_fire_mode][stance]["play_rate"]
	
	# Fallback to semi standing rate
	return semi_fire_rate


# Traverses up the tree to find the player node
func get_weapon_owner() -> Player:
	var node = get_parent()
	while node:
		if node is Player:
			return node
		node = node.get_parent()
	return null


# Tries to find the player from a collider
func _get_player_from_collider(collider: Object) -> Player:
	# Try to get the player directly if it's a Player node
	if collider is Player:
		return collider
	
	# Otherwise, traverse up the tree to find the Player node
	var node = collider
	while node and not (node is Player):
		node = node.get_parent()
	
	return node as Player


# Common processing for hits and damage reporting
func process_hits_for_damage(hit_positions: Array[Vector3]) -> Dictionary:
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	var hits_by_target: Dictionary = {} # target_id -> array of hits
	
	for hit_position in hit_positions:
		# We need to raycast to see what we hit at each position
		var direction: Vector3 = (hit_position - muzzle_position).normalized()
		var hit: Dictionary = weapon_raycast(muzzle_position, direction)
		
		if hit:
			var collider = hit.get("collider")
			
			# If we hit a Player
			if collider and (collider.is_in_group("body_material") or collider.is_in_group("headshot_material")):
				# Try to find the player node from the collider
				var hit_player = _get_player_from_collider(collider)
				# If we found the player and is still alive
				if hit_player and hit_player.is_alive():
					# We check if this was a headshot or not
					var is_critical: bool = false
					if collider.is_in_group("headshot_material"):
						is_critical = true
					
					# Store hit in dictionary
					var target_id: int = hit_player.player_id
					if not hits_by_target.has(target_id):
						hits_by_target[target_id] = []
					
					hits_by_target[target_id].append({
						"position": hit.position,
						"is_critical": is_critical
					})
			
			# Play impact and sound effects
			_play_impact_effects(hit, collider)
	
	return hits_by_target


# Helper function to play impact effects based on material
func _play_impact_effects(hit: Dictionary, collider: Object) -> void:
	if not collider:
		return
	
	if collider.is_in_group("body_material"):
		SfxManager.spawn_projectile_impact_body(hit.position, hit.normal)
		AudioManager.play_bullet_impact_body(hit.position)
	elif collider.is_in_group("headshot_material"):
		SfxManager.spawn_projectile_impact_headshot(hit.position, hit.normal)
		AudioManager.play_bullet_impact_headshot(hit.position)
	elif collider.is_in_group("concrete_material"):
		SfxManager.spawn_projectile_impact_decal(hit.position, hit.normal, collider, "concrete_material")
		SfxManager.spawn_projectile_impact_concrete(hit.position, hit.normal)
		AudioManager.play_bullet_impact_concrete(hit.position)
	# Add more material types as needed


# Common function for spawning bullet tracers
func _spawn_bullet_tracer(from_position: Vector3, to_position: Vector3) -> void:
	var tracer := BULLET_TRACER.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.initialize(from_position, to_position)
	
	# Debug visualization if active
	if debug:
		if DebugDraw3D:
			var debug_color = Color.GREEN
			DebugDraw3D.draw_line(from_position, to_position, debug_color, debug_duration)
			
