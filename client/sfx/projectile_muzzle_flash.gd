extends Node

@export var MUZZLE_FLASH_RATIO: float = 0.5

@onready var muzzle: GPUParticles3D = $Muzzle
@onready var flash: GPUParticles3D = $Flash
@onready var smoke: GPUParticles3D = $Smoke
@onready var sparks: GPUParticles3D = $Sparks


# Preload textures for the muzzle flash
var muzzle_textures = [
	preload("res://assets/textures/sfx/muzzle/muzzle_01_rotated.png"),
	preload("res://assets/textures/sfx/muzzle/muzzle_02_rotated.png"),
	preload("res://assets/textures/sfx/muzzle/muzzle_03_rotated.png"),
	preload("res://assets/textures/sfx/muzzle/muzzle_04_rotated.png"),
	preload("res://assets/textures/sfx/muzzle/muzzle_05_rotated.png")
]


func restart() -> void:
	# Determine if we had a muzzle flash this shot
	if randf() <= MUZZLE_FLASH_RATIO:
		_update_muzzle_texture()
		muzzle.restart()
		flash.restart()
	# Always show sparks and smoke, flash or not
	smoke.restart()
	sparks.restart()


func _update_muzzle_texture() -> void:
	# Pick a random texture index
	var texture_index: int = randi() % muzzle_textures.size()
	# Get material override
	var material: Material = muzzle.material_override
	# Validate material type before setting the texture
	if material is StandardMaterial3D:
		material.albedo_texture = muzzle_textures[texture_index]
	elif material is ShaderMaterial:
		material.set_shader_parameter("albedo_texture", muzzle_textures[texture_index])
