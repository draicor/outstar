extends ProjectileWeapon
class_name ProjectileShotgun

# This is how we will spawn the correct weapon model
enum Shotguns { REMINGTON870 }
var ShotgunType: Dictionary[Shotguns, String] = {
	Shotguns.REMINGTON870: "remington870_shotgun",
}
# Shotgun default stats
# Remington870 30 RPM
# 1.0 single fire rate, 1.0 hrecoil, 1.0 vrecoil, 1.0 lower_recoil
# 4.0 spread_angle, 9 pellet_count, 35 max_distance

@export var weapon_model: Shotguns = Shotguns.REMINGTON870

# Recoil stats
@export var spread_angle: float = 3.0 # degrees of spread
@export var pellet_count: int = 9 # Number of pellets per shot


func _ready() -> void:
	calculate_recoil()
	_initialize_fire_rates()


# Sets the dictionary variables that will control the attack speed of this weapon
func _initialize_fire_rates() -> void:
	fire_rates = {
		FireModes.SEMI: {
			"standing": {
				"play_rate": semi_fire_rate
			},
			"crouching": {
				"play_rate": semi_fire_rate
			}
		},
		FireModes.AUTO: {
			"standing": {
				"play_rate": auto_fire_rate
			},
			"crouching": {
				"play_rate": auto_fire_rate
			}
		}
	}


func calculate_hit_positions(direction: Vector3 = Vector3.ZERO) -> Array[Vector3]:
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# Set target direction if provided
	if direction != Vector3.ZERO:
		# Create horizontal direction (ignoring weapon's vertical angle)
		target_direction = direction.normalized()
	
	var main_target: Vector3 = _apply_recoil(target_direction)
	var hit_positions: Array[Vector3] = []
	
	# Calculate hit positions for all pellets
	for i in range(pellet_count):
		var pellet_direction: Vector3 = _get_pellet_direction(main_target)
		var hit: Dictionary = weapon_raycast(muzzle_position, pellet_direction)
		var pellet_hit_position: Vector3 = hit.position if hit else muzzle_position + pellet_direction * weapon_max_distance
		hit_positions.append(pellet_hit_position)
	
	return hit_positions


func fire(hit_positions: Array[Vector3]) -> void:
	# Get weapon muzzle position
	var muzzle_position: Vector3 = muzzle_marker_3d.global_position
	
	# We already checked if we can fire in player_equipment.weapon_fire()
	projectile_muzzle_flash.restart()
	
	# Fire tracers for each hit position
	if hit_positions.size() > 0:
		for hit_position in hit_positions:
			_spawn_bullet_tracer(muzzle_position, hit_position)


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
