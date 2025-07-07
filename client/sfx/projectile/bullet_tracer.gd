extends Node3D

@export var bullet_scene: PackedScene
@export_range(1, 10) var max_bullets: int = 5
@export_range(0.01, 0.2) var base_travel_time: float = 0.05 # Total base visual travel time
@export var min_distance: float = 1.0 # Minimum shooting distance
@export var max_distance: float = 50.0 # Maximum shooting distance


func initialize(start: Vector3, end: Vector3) -> void:
	var direction = (end - start).normalized()
	var distance = start.distance_to(end)
	
	# If the target is too close, don't spawn any bullets
	if distance < 1.0:
		queue_free()
		return
	
	# Calculate bullet count based on distance
	var bullet_count = int(ceil(lerp(1, max_bullets, inverse_lerp(min_distance, max_distance, distance))))
	
	# Adjust travel time based on distance (faster for closer targets)
	var travel_time = base_travel_time * clamp(distance / max_distance, 0.1, 1.0)
	
	# Calculate bullet positions
	var positions = []
	for i in range(bullet_count):
		# Progress from 0.1 to 0.9
		var progress = lerp(0.1, 0.9, float(i) / (bullet_count - 1))
		positions.append(start.lerp(end, progress))
	
	# Spawn bullets with progressive delays
	for i in range(bullet_count):
		var delay = travel_time * (float(i) / bullet_count)
		await get_tree().create_timer(delay).timeout
		
		# Spawn the bullet
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = positions[i]
		bullet.look_at(positions[i] + direction)
	
	# Remove the tracer after all segments are spawned
	queue_free()
