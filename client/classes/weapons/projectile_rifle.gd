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
			"standing": {
				"animation": "rifle/rifle_aim_fire_single_fast",
				"play_rate": semi_fire_rate
			},
			"crouching": {
				"animation": "rifle/rifle_crouch_aim_fire_single_low_recoil",
				"play_rate": semi_fire_rate * 1.556 # To match shooting standing speed
			}
		},
		FireModes.AUTO: {
			"standing": {
				"animation": "rifle/rifle_aim_fire_single_fast",
				"play_rate": auto_fire_rate
			},
			"crouching": {
				"animation": "rifle/rifle_crouch_aim_fire_single_low_recoil",
				"play_rate": auto_fire_rate * 1.556 # To match shooting standing speed
			}
		}
	}


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
		#if DebugDraw3D:
			#var color: Color = Color.RED if results.size() > 0 else Color.GREEN
			#DebugDraw3D.draw_sphere(check_position, 0.04, color, 0.2)
		
		if results.size() > 0:
			return true
	
	# No collision
	return false


func calculate_hit_positions(direction: Vector3 = Vector3.ZERO) -> Array[Vector3]:
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
	
	# Return array with a single hit for compatibility
	return [hit_position]


func fire(hits: Array[Vector3]) -> void:
	if hits.is_empty():
		push_error("Error inside projectile_rifle fire(), hits array is empty.")
		return
	
	var hit_position: Vector3 = hits[0]
	
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# We already have the hit position, so we don't need to calculate recoil again
	
	# We already checked if we can fire in player_equipment.weapon_fire()
	projectile_muzzle_flash.restart()
	# Add the bullet tracer
	var tracer := BULLET_TRACER.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.initialize(muzzle_position, hit_position)
	
	if debug:
		var debug_color = Color.GREEN
		DebugDraw3D.draw_line(muzzle_position, hit_position, debug_color, debug_duration)


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
# It always starts in the semi automatic mode, which is the default of all firearms
func toggle_fire_mode() -> void:
	if has_multiple_modes:
		current_fire_mode = (current_fire_mode + 1) % FireModes.size() as FireModes
		calculate_recoil()


func set_fire_mode(mode: int) -> void:
	current_fire_mode = mode as FireModes
	calculate_recoil()


# Returns the appropriate animation based on stance and fire mode
func get_animation() -> String:
	var owner_player: Player = get_weapon_owner()
	if not owner_player:
		return fire_rates[FireModes.SEMI]["standing"]["animation"]
	
	var current_state: String = owner_player.player_state_machine.get_current_state_name()
	var stance: String = "standing"
	
	# Check if we are in crouch aim state
	if current_state == "rifle_crouch_aim_idle":
		stance = "crouching"
	
	return fire_rates[current_fire_mode][stance]["animation"]


# Returns the appropriate animation play rate based on stance and fire mode
func get_animation_play_rate() -> float:
	var owner_player: Player = get_weapon_owner()
	if not owner_player:
		return fire_rates[FireModes.SEMI]["standing"]["play_rate"]
	
	var current_state: String = owner_player.player_state_machine.get_current_state_name()
	var stance: String = "standing"
	
	# Check if we are in crouch aim state
	if current_state == "rifle_crouch_aim_idle":
		stance = "crouching"
	
	return fire_rates[current_fire_mode][stance]["play_rate"]


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


# Process hits and group them by target
func process_hits_for_damage(hit_positions: Array[Vector3]) -> Dictionary:
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	var hits_by_target: Dictionary = {} # target_id -> single hit
	
	if hit_positions.size() > 0:
		var hit_position = hit_positions[0]
		# We need to raycast to see what we hit
		var direction = (hit_position - muzzle_position).normalized()
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
					
					hits_by_target[target_id] = [{
						"position": hit.position,
						"is_critical": is_critical
					}]
			
			# elif:
			# Add here the code to report damage to destructibles!
			
			# Play impact and sound effects
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
	
	return hits_by_target
