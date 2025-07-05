extends GPUParticles3D
class_name DisposableGPUParticles3D


# Destroy this after the lifetime ends
func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime).timeout
	queue_free()
