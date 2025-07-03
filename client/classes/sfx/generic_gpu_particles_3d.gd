extends Node


func restart() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.restart()
