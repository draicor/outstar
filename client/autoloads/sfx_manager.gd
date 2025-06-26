extends Node


# Preloading scenes
const projectile_blood_splatter_01_scene = preload("res://sfx/projectile_blood_splatter_01.tscn")


func spawn_projectile_blood_splatter(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	var projectile_blood_splatter_01 := projectile_blood_splatter_01_scene.instantiate()
	
	# Add to scene
	add_child(projectile_blood_splatter_01)
	
	# Position and orient blood
	projectile_blood_splatter_01.global_position = spawn_position
	# Use the reverse of the normal for bullet impacts (position - normal)
	projectile_blood_splatter_01.look_at(spawn_position - spawn_normal, Vector3.UP)
