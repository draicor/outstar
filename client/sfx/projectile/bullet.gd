extends Node3D

var lifetime = 0.02 # Very short visible time


func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()
