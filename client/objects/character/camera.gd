extends Node3D

@onready var background_camera: Camera3D = $BaseCamera/BackgroundContainer/BackgroundViewport/BackgroundCamera
@onready var foreground_camera: Camera3D = $BaseCamera/ForegroundContainer/ForegroundViewport/ForegroundCamera

func _process(delta: float) -> void:
	# Every frame, we copy the camera's origin position into our cameras
	background_camera.global_transform = GameManager.player_character.camera_origin.global_transform
	foreground_camera.global_transform = GameManager.player_character.camera_origin.global_transform
