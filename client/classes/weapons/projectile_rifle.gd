extends ProjectileWeapon
class_name ProjectileRifle

# This is how we will spawn the correct weapon model
enum Rifles { M16, AKM }
var RifleType: Dictionary[Rifles, String] = {
	Rifles.M16: "m16_rifle",
	Rifles.AKM: "akm_rifle",
}
# Automatic rifle default stats
# M16 800 RPM:
# 4.0 auto fire rate, 1.0 semi fire rate, 1.2 hrecoil, 1.3 vrecoil, 4.5 lowerrecoil
# 2.0 automatic_mode_extra_recoil 2.0, 50 max distance

# AKM 600 RPM:
# 3.0 fire rate, 1.0 semi fire rate, 1.4 hrecoil, 1.7 vrecoil, 4.5 lowerrecoil
# 2.0 automatic_mode_extra_recoil, 50 max distance

@export var weapon_model: Rifles = Rifles.M16

# Recoil stats
@export var automatic_mode_extra_recoil: float = 2.0


func _ready() -> void:
	calculate_recoil()
	_initialize_fire_rates()


# Calculate the recoil deviation angles,
# If the recoil stats change for any reason (crouching, status effects),
# Then we have to call this function again for it to take effect!
func calculate_recoil() -> void:
	super.calculate_recoil()
	
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
				"play_rate": semi_fire_rate
			},
			"crouching": {
				"play_rate": semi_fire_rate * 1.556 # To match shooting standing speed
			}
		},
		FireModes.AUTO: {
			"standing": {
				"play_rate": auto_fire_rate
			},
			"crouching": {
				"play_rate": auto_fire_rate * 1.556 # To match shooting standing speed
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
	_spawn_bullet_tracer(muzzle_position, hit_position)
