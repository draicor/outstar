extends Node3D
class_name PlayerAudio

# Projectile rifle fire sounds
const PROJECTILE_RIFLE_FIRE_SINGLE = preload("res://assets/sounds/sfx/projectile_rifle_fire_single.wav")
const PROJECTILE_RIFLE_DRY_FIRE_SINGLE = preload("res://assets/sounds/sfx/projectile_rifle_dry_fire_single.wav")
# Projectile rifle reload sounds
const PROJECTILE_RIFLE_REMOVE_MAGAZINE = preload("res://assets/sounds/sfx/projectile_rifle_remove_magazine.wav")
const PROJECTILE_RIFLE_INSERT_MAGAZINE = preload("res://assets/sounds/sfx/projectile_rifle_insert_magazine.wav")
const PROJECTILE_RIFLE_CHARGING_HANDLE = preload("res://assets/sounds/sfx/projectile_rifle_charging handle.wav")


# Preloading scripts
const Player: GDScript = preload("res://objects/player/player.gd")

# Internal variables
var player: Player = null # Our parent node

# AudioStreamPlayer3D Fire pool
var audio_players_3d: Array[AudioStreamPlayer3D] = []
var current_audio_players_3d_index: int = 0
# AudioStreamPlayer3D Reload pool
var remove_magazine_audio_player_3d: AudioStreamPlayer3D
var insert_magazine_audio_player_3d: AudioStreamPlayer3D
var charging_handle_audio_player_3d: AudioStreamPlayer3D


# Setup
const POOL_SIZE: int = 5 # Number of overlapping sounds
const BASE_VOLUME: float = 0.0 # Base volume in DB
const MAX_DISTANCE: float = 100.0 # Max sound distance in meters

# Animation events (timing for each animation)
var current_animation: String = ""
var animation_start_time: float = 0.0
var triggered_events: Dictionary = {}
var animation_events: Dictionary[String, Array] = {
	"rifle/rifle_aim_fire_single_fast": [
		{"time": 0.1, "method": "play_3d_sound", "args": []},
	],
	"rifle/rifle_aim_reload_fast": [
		{"time": 0.7, "method": "play_projectile_rifle_remove_magazine", "args": []},
		{"time": 1.6, "method": "play_projectile_rifle_insert_magazine", "args": []},
		{"time": 2.1, "method": "play_projectile_rifle_charging_handle", "args": []},
	]
}


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	player = get_parent()
	
	# Create pool of audio players for rifle pool
	for i in POOL_SIZE:
		var new_audio_player_3d = AudioStreamPlayer3D.new()
		# Setup this audio player
		new_audio_player_3d.stream = PROJECTILE_RIFLE_DRY_FIRE_SINGLE
		new_audio_player_3d.volume_db = BASE_VOLUME
		new_audio_player_3d.max_distance = MAX_DISTANCE
		new_audio_player_3d.bus = "SFX"
		# Add it to our scene and to our array of audio players
		add_child(new_audio_player_3d)
		audio_players_3d.append(new_audio_player_3d)
	
	# Create reload audio players
	remove_magazine_audio_player_3d = create_single_audio_player_3d(PROJECTILE_RIFLE_REMOVE_MAGAZINE, 8.0, 15.0, "SFX")
	insert_magazine_audio_player_3d = create_single_audio_player_3d(PROJECTILE_RIFLE_INSERT_MAGAZINE, 8.0, 15.0, "SFX")
	charging_handle_audio_player_3d = create_single_audio_player_3d(PROJECTILE_RIFLE_CHARGING_HANDLE, 15.0, 20.0, "SFX")
	
	# Connect to animation player signals to check every frame to call anim events
	player.player_animator.animation_player.connect("animation_started", _on_animation_started)
	player.player_animator.animation_player.connect("animation_finished", _on_animation_finished)


# Runs on tick to check for animation_events
func _process(_delta: float) -> void:
	if current_animation != "" and animation_events.has(current_animation):
		check_animation_events()


# NOTE rework this function to receive a string to play the right sound
func play_3d_sound() -> void:
	# Get the next available audio player 3d using round-robin
	var audio_player_3d: AudioStreamPlayer3D = audio_players_3d[current_audio_players_3d_index]
	# Reset player if it's still playing
	if audio_player_3d.playing:
		audio_player_3d.stop()
	
	# Slight pitch variation
	audio_player_3d.pitch_scale = randf_range(0.95, 1.05)  
	# Play sound
	audio_player_3d.play()
	
	# Update index for next sound
	current_audio_players_3d_index = (current_audio_players_3d_index + 1) % POOL_SIZE


# Connected to the animation player signal
func _on_animation_started(anim_name: String) -> void:
	current_animation = anim_name
	animation_start_time = Time.get_ticks_msec()
	triggered_events.clear()


# Connected to the animation player signal
func _on_animation_finished(_anim_name: String) -> void:
	current_animation = ""


func check_animation_events() -> void:
	if not animation_events.has(current_animation):
		return
	
	var current_time: float = player.player_animator.animation_player.current_animation_position
	
	for event in animation_events[current_animation]:
		var event_id: String = str(event["time"])
		
		# Only trigger if we're past the event time and haven't triggered it yet
		if current_time >= event["time"] and not triggered_events.get(event_id, false):
			# Check if we are still within a reasonable time window
			if current_time < event["time"] + 0.1: # 100ms tolerance
				callv(event["method"], event["args"])
				triggered_events[event_id] = true


func create_single_audio_player_3d(stream: AudioStream, volume_db: float, max_distance: float, bus: String) -> AudioStreamPlayer3D:
	var audio_player_3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio_player_3d.stream = stream
	audio_player_3d.volume_db = volume_db
	audio_player_3d.max_distance = max_distance
	audio_player_3d.bus = bus
	add_child(audio_player_3d)
	return audio_player_3d


func play_projectile_rifle_remove_magazine() -> void:
	if remove_magazine_audio_player_3d.playing:
		return # Don't interrupt ongoing sound
	
	remove_magazine_audio_player_3d.pitch_scale = randf_range(0.95, 1.05)
	remove_magazine_audio_player_3d.play()


func play_projectile_rifle_insert_magazine() -> void:
	if insert_magazine_audio_player_3d.playing:
		return # Don't interrupt ongoing sound
	
	insert_magazine_audio_player_3d.pitch_scale = randf_range(0.95, 1.05)
	insert_magazine_audio_player_3d.play()


func play_projectile_rifle_charging_handle() -> void:
	if charging_handle_audio_player_3d.playing:
		return # Don't interrupt ongoing sound
	
	charging_handle_audio_player_3d.pitch_scale = randf_range(0.98, 1.02)
	charging_handle_audio_player_3d.play()
