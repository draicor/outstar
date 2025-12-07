extends Node3D
class_name ProjectileShotgun

# This is how we will spawn the correct weapon model
enum FireModes { SEMI, AUTO }
enum Shotguns { REMINGTON870 }
var ShotgunType: Dictionary[Shotguns, String] = {
	Shotguns.REMINGTON870: "remington870_shotgun",
}
# Shotgun default stats
# Remington870 30 RPM -> 1.0 fire rate, x hrecoil, y vrecoil

@export var weapon_model: Shotguns = Shotguns.REMINGTON870
# Debug
@export var debug: bool = false
@export var debug_duration: float = 0.2
# Weapon stats
@export var weapon_max_distance: float = 25.0 # meters

# Recoil stats
@export var spread_angle: float = 15.0 # degrees of spread
@export var pellet_count: int = 9 # Number of pellets per shot
@export var horizontal_recoil: float = 2.0
@export var vertical_recoil: float = 3.0
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
@export var has_multiple_modes: bool = false
@export var semi_fire_rate: float = 1.0
@export var auto_fire_rate: float = 1.0 # CAUTION not used yet
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


# Sets the dictionary variables that will control the attack speed of this weapon
func _initialize_fire_rates() -> void:
	fire_rates = {
		FireModes.SEMI: {
			"standing": {
				"animation": "shotgun/shotgun_aim_fire",
				"play_rate": semi_fire_rate
			},
			"crouching": {
				"animation": "shotgun/shotgun_crouch_aim_fire",
				"play_rate": semi_fire_rate
			}
		},
		FireModes.AUTO: {
			"standing": {
				"animation": "shotgun/shotgun_aim_fire",
				"play_rate": auto_fire_rate
			},
			"crouching": {
				"animation": "shotgun/shotgun_crouch_aim_fire",
				"play_rate": auto_fire_rate
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


func fire(direction: Vector3 = Vector3.ZERO) -> Vector3:
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# If we forgot to set this, at least it will fire in the same direction
	if direction == Vector3.ZERO:
		# Create horizontal direction (ignoring weapon's vertical angle)
		target_direction = -muzzle_marker_3d.global_transform.basis.z
	
	var main_target: Vector3 = _apply_recoil(target_direction)
	var hit_position: Vector3 = muzzle_position + main_target * weapon_max_distance
	
	# We already checked if we can fire in player_equipment.weapon_fire()
	projectile_muzzle_flash.restart()
	
	# Fire multiple pellets
	for i in range(pellet_count):
		var pellet_direction: Vector3 = _get_pellet_direction(main_target)
		var hit: Dictionary = weapon_raycast(muzzle_position, pellet_direction)
		var pellet_hit_position: Vector3 = hit.position if hit else muzzle_position + pellet_direction * weapon_max_distance
		
		# Add the bullet tracer
		var tracer := BULLET_TRACER.instantiate()
		get_tree().current_scene.add_child(tracer)
		tracer.initialize(muzzle_position, pellet_hit_position)
		
		if debug:
			var debug_color = Color.GREEN if hit else Color.RED
			DebugDraw3D.draw_line(muzzle_position, pellet_hit_position, debug_color, debug_duration)
	
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


# Get direction for each individual pellet with spread
func _get_pellet_direction(base_direction: Vector3) -> Vector3:
	var spread_vector: Vector3 = base_direction
	
	# Apply random spread
	var spread_yaw: float = deg_to_rad(randf_range(-spread_angle, spread_angle))
	var spread_pitch: float = deg_to_rad(randf_range(-spread_angle, spread_angle))
	
	# Apply yaw spread
	spread_vector = spread_vector.rotated(Vector3.UP, spread_yaw)
	# Apply pitch spread
	var right: Vector3 = spread_vector.cross(Vector3.UP).normalized()
	spread_vector = spread_vector.rotated(right, spread_pitch)
	
	return spread_vector.normalized()


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
	if current_state == "shotgun_crouch_aim_idle":
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
	if current_state == "shotgun_crouch_aim_idle":
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


func _process_hit(hit: Dictionary) -> void:
	var collider = hit.get("collider")
	
	# If we hit a Player
	if collider and (collider.is_in_group("body_material") or collider.is_in_group("headshot_material")):
		# Try to find the player node from the collider
		var hit_player = _get_player_from_collider(collider)
		if hit_player:
			# If the player is not alive, ignore
			# Check here, so this ignores for all players
			if not hit_player.is_alive():
				return
			
			# Check if this weapon belongs to the local player
			var owner_player = get_weapon_owner()
			if owner_player and owner_player.is_local_player:
				# We check if this was a headshot or not
				var is_critical: bool = false
				if collider.is_in_group("headshot_material"):
					is_critical = true
				
				# Report to server
				owner_player.player_packets.send_report_player_damage_packet(
					hit_player.player_id,
					hit.position,
					is_critical
				)
		
		# CAUTION
		# else:
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
