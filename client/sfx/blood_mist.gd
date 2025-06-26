extends GPUParticles3D


# CAUTION use a pool instead of this shit
func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime).timeout
	queue_free()
