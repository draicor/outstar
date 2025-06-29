extends Node


# Preloading scenes
const projectile_impact_flesh_scene = preload("res://sfx/projectile_impact_flesh.tscn")
const projectile_impact_concrete_scene = preload("res://sfx/projectile_impact_concrete.tscn")


func spawn_projectile_impact_flesh(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	var projectile_impact_flesh := projectile_impact_flesh_scene.instantiate()
	
	# Add to scene
	add_child(projectile_impact_flesh)
	
	# Position and orient sfx
	projectile_impact_flesh.global_position = spawn_position
	# Use the reverse of the normal for bullet impacts (position - normal)
	projectile_impact_flesh.look_at(spawn_position - spawn_normal, Vector3.UP)


func spawn_projectile_impact_concrete(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	var projectile_impact_concrete := projectile_impact_concrete_scene.instantiate()
	
	# Add to scene
	add_child(projectile_impact_concrete)
	
	# Position and orient sfx
	projectile_impact_concrete.global_position = spawn_position
	# Use the reverse of the normal for bullet impacts (position - normal)
	projectile_impact_concrete.look_at(spawn_position - spawn_normal, Vector3.UP)
