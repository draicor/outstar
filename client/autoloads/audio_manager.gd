extends Node


# Audio Pools
# BULLET IMPACT #
# Concrete sounds #
const BULLET_IMPACT_CONCRETE_SOUNDS = [
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_01.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_02.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_03.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_04.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_05.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_06.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_07.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/concrete/bullet_impact_concrete_08.wav"),
]
# Body sounds #
const BULLET_IMPACT_BODY_SOUNDS = [
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_01.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_02.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_03.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_04.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_05.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_06.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_07.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/body/bullet_impact_body_08.wav"),
]
# Headshot sounds #
const BULLET_IMPACT_HEADSHOT_SOUNDS = [
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_01.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_02.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_03.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_04.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_05.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_06.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_07.wav"),
	preload("res://assets/sounds/sfx/bullet/impact/headshot/bullet_impact_headshot_08.wav"),
]
# Audio pools
var audio_player_pool: Array[AudioStreamPlayer3D] = []
const AUDIO_POOL_SIZE: int = 32
var audio_pool_index: int = 0
# Audio settings
const BULLET_IMPACT_VOLUME: float = -5.0
const BULLET_IMPACT_MAX_DISTANCE: float = 40.0


func _ready() -> void:
	# Initialize audio pool
	for i in AUDIO_POOL_SIZE:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.bus = "SFX"
		add_child(audio_player)
		audio_player_pool.append(audio_player)


# Generic function to play any 3D sound at a world position
func play_sound_3d_at_location(stream: AudioStream, position: Vector3, volume_db: float = 0.0, max_distance: float = 40.0, pitch_variation: bool = true) -> void:
	var audio_player: AudioStreamPlayer3D = audio_player_pool[audio_pool_index]
	
	# Reset player if it's still playing
	if audio_player.playing:
		audio_player.stop()
	
	# Configure the audio player
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	audio_player.max_distance = max_distance
	audio_player.global_position = position
	
	# Add slight pitch variation if requested
	if pitch_variation:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
	else:
		audio_player.pitch_scale = 1.0
	
	audio_player.play()
	
	# Update index for round-robin
	audio_pool_index = (audio_pool_index + 1) % AUDIO_POOL_SIZE


func play_bullet_impact_concrete(position: Vector3) -> void:
	var sound_to_play = BULLET_IMPACT_CONCRETE_SOUNDS[randi() % BULLET_IMPACT_CONCRETE_SOUNDS.size()]
	play_sound_3d_at_location(sound_to_play, position, BULLET_IMPACT_VOLUME, BULLET_IMPACT_MAX_DISTANCE)


func play_bullet_impact_body(position: Vector3) -> void:
	var sound_to_play = BULLET_IMPACT_BODY_SOUNDS[randi() % BULLET_IMPACT_BODY_SOUNDS.size()]
	play_sound_3d_at_location(sound_to_play, position, BULLET_IMPACT_VOLUME, BULLET_IMPACT_MAX_DISTANCE)


func play_bullet_impact_headshot(position: Vector3) -> void:
	var sound_to_play = BULLET_IMPACT_HEADSHOT_SOUNDS[randi() % BULLET_IMPACT_HEADSHOT_SOUNDS.size()]
	play_sound_3d_at_location(sound_to_play, position, BULLET_IMPACT_VOLUME, BULLET_IMPACT_MAX_DISTANCE)
