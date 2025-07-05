extends Node

@export var MUZZLE_FLASH_RATIO: float = 0.5

@onready var muzzle: GPUParticles3D = $Muzzle
@onready var flash: GPUParticles3D = $Flash
@onready var smoke: GPUParticles3D = $Smoke
@onready var sparks: GPUParticles3D = $Sparks


func restart() -> void:
	# Determine if we had a muzzle flash this shot
	if randf() <= MUZZLE_FLASH_RATIO:
		muzzle.restart()
		flash.restart()
	# Always show sparks and smoke, flash or not
	smoke.restart()
	sparks.restart()
