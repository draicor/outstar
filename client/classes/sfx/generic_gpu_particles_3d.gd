extends Node


# Get every child of this class and restart each individual particle
func restart() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.restart()
