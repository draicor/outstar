extends Node

const blood_mist_scene = preload("res://sfx/blood_mist.tscn")


func spawn_blood_mist(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	var blood_mist := blood_mist_scene.instantiate()
	
	# Add to scene
	add_child(blood_mist)
	
	# Position and orient blood
	blood_mist.global_position = spawn_position
	# Use the reverse of the normal for bullet impacts (position - normal)
	blood_mist.look_at(spawn_position - spawn_normal, Vector3.UP)
