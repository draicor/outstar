extends Node3D
class_name PlayerAudio

# M16 rifle sounds
const M16_RIFLE_CHARGING_HANDLE = preload("res://assets/sounds/sfx/rifle/m16_rifle/m16_rifle_charging_handle.wav")
const M16_RIFLE_DRY_FIRE_SINGLE = preload("res://assets/sounds/sfx/rifle/m16_rifle/m16_rifle_dry_fire_single.wav")
const M16_RIFLE_FIRE_SINGLE = preload("res://assets/sounds/sfx/rifle/m16_rifle/m16_rifle_fire_single.wav")
const M16_RIFLE_INSERT_MAGAZINE = preload("res://assets/sounds/sfx/rifle/m16_rifle/m16_rifle_insert_magazine.wav")
const M16_RIFLE_FIRE_MODE_SELECTOR = preload("res://assets/sounds/sfx/rifle/m16_rifle/m16_rifle_fire_mode_selector.wav")
const M16_RIFLE_REMOVE_MAGAZINE = preload("res://assets/sounds/sfx/rifle/m16_rifle/m16_rifle_remove_magazine.wav")
# AKM rifle sounds
const AKM_RIFLE_CHARGING_HANDLE = preload("res://assets/sounds/sfx/rifle/akm_rifle/akm_rifle_charging handle.wav")
const AKM_RIFLE_DRY_FIRE_SINGLE = preload("res://assets/sounds/sfx/rifle/akm_rifle/akm_rifle_dry_fire_single.wav")
const AKM_RIFLE_FIRE_MODE_SELECTOR = preload("res://assets/sounds/sfx/rifle/akm_rifle/akm_rifle_fire_mode_selector.wav")
const AKM_RIFLE_FIRE_SINGLE = preload("res://assets/sounds/sfx/rifle/akm_rifle/akm_rifle_fire_single.wav")
const AKM_RIFLE_INSERT_MAGAZINE = preload("res://assets/sounds/sfx/rifle/akm_rifle/akm_rifle_insert_magazine.wav")
const AKM_RIFLE_REMOVE_MAGAZINE = preload("res://assets/sounds/sfx/rifle/akm_rifle/akm_rifle_remove_magazine.wav")


# Internal variables
var player: Player = null # Our parent node

# AudioStreamPlayer3D pools
var current_weapon_fire_single_audio_pool: Array[AudioStreamPlayer3D] = []
var current_weapon_dry_fire_single_audio_pool: Array[AudioStreamPlayer3D] = []
# Audio Pool Indexes
var current_weapon_fire_single_index: int = 0
var current_weapon_dry_fire_single_index: int = 0
# AudioStreamPlayer3D reload audio players
var remove_magazine_audio_player_3d: AudioStreamPlayer3D
var insert_magazine_audio_player_3d: AudioStreamPlayer3D
var charging_handle_audio_player_3d: AudioStreamPlayer3D
# AudioStreamPlayer mode selector audio player
var fire_mode_selector_audio_player: AudioStreamPlayer


# General Setup
const MAX_DISTANCE: float = 80.0 # Max sound distance in meters
const POOL_SIZE: int = 5 # Number of overlapping sounds
# M16 RIFLE Setup
const M16_RIFLE_FIRE_VOLUME: float = -5.0 # Base volume in DB
const M16_RIFLE_DRY_FIRE_VOLUME: float = -10.0 # Base volume in DB
# AKM RIFLE Setup
const AKM_RIFLE_FIRE_VOLUME: float = 0.0 # Base volume in DB
const AKM_RIFLE_DRY_FIRE_VOLUME: float = -14.0 # Base volume in DB


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	player = get_parent()


func setup_weapon_audio_players(weapon_name: String) -> void:
	match weapon_name:
		"m16_rifle":
			_initialize_m16_weapon_audio_players()
		"akm_rifle":
			_initialize_akm_weapon_audio_players()
		"_":
			push_error("Error trying to setup %s sounds" % weapon_name)


func _initialize_m16_weapon_audio_players() -> void:
	# Clear the active audio pool
	current_weapon_fire_single_audio_pool.clear()
	current_weapon_dry_fire_single_audio_pool.clear()
	
	# Create pools of audio players
	for i in POOL_SIZE:
		# Weapon single fire sound
		var weapon_fire_single_audio_player: AudioStreamPlayer3D = create_single_audio_player_3d(
			M16_RIFLE_FIRE_SINGLE,
			M16_RIFLE_FIRE_VOLUME,
			MAX_DISTANCE,
			"SFX"
		)
		current_weapon_fire_single_audio_pool.append(weapon_fire_single_audio_player)
		
		# Weapon single dry fire sound
		var weapon_dry_fire_single_audio_player: AudioStreamPlayer3D = create_single_audio_player_3d(
			M16_RIFLE_DRY_FIRE_SINGLE,
			M16_RIFLE_DRY_FIRE_VOLUME,
			MAX_DISTANCE,
			"SFX"
		)
		current_weapon_dry_fire_single_audio_pool.append(weapon_dry_fire_single_audio_player)
	
	# Create reload audio players
	remove_magazine_audio_player_3d = create_single_audio_player_3d(M16_RIFLE_REMOVE_MAGAZINE, 8.0, 20.0, "SFX")
	insert_magazine_audio_player_3d = create_single_audio_player_3d(M16_RIFLE_INSERT_MAGAZINE, 8.0, 20.0, "SFX")
	charging_handle_audio_player_3d = create_single_audio_player_3d(M16_RIFLE_CHARGING_HANDLE, 15.0, 20.0, "SFX")
	# Create fire mode selector audio player
	fire_mode_selector_audio_player = create_single_audio_player(M16_RIFLE_FIRE_MODE_SELECTOR, -1.0, "SFX")
	# Reset indexes
	current_weapon_fire_single_index = 0
	current_weapon_dry_fire_single_index = 0


func _initialize_akm_weapon_audio_players() -> void:
	# Clear the active audio pool
	current_weapon_fire_single_audio_pool.clear()
	current_weapon_dry_fire_single_audio_pool.clear()
	
	# Create pools of audio players
	for i in POOL_SIZE:
		# Weapon single fire sound
		var weapon_fire_single_audio_player: AudioStreamPlayer3D = create_single_audio_player_3d(
			AKM_RIFLE_FIRE_SINGLE,
			AKM_RIFLE_FIRE_VOLUME,
			MAX_DISTANCE,
			"SFX"
		)
		current_weapon_fire_single_audio_pool.append(weapon_fire_single_audio_player)
		
		# Weapon single dry fire sound
		var weapon_dry_fire_single_audio_player: AudioStreamPlayer3D = create_single_audio_player_3d(
			AKM_RIFLE_DRY_FIRE_SINGLE,
			AKM_RIFLE_DRY_FIRE_VOLUME,
			MAX_DISTANCE,
			"SFX"
		)
		current_weapon_dry_fire_single_audio_pool.append(weapon_dry_fire_single_audio_player)
	
	# Create reload audio players
	remove_magazine_audio_player_3d = create_single_audio_player_3d(AKM_RIFLE_REMOVE_MAGAZINE, 8.0, 20.0, "SFX")
	insert_magazine_audio_player_3d = create_single_audio_player_3d(AKM_RIFLE_INSERT_MAGAZINE, 8.0, 20.0, "SFX")
	charging_handle_audio_player_3d = create_single_audio_player_3d(AKM_RIFLE_CHARGING_HANDLE, 15.0, 20.0, "SFX")
	# Create fire mode selector audio player
	fire_mode_selector_audio_player = create_single_audio_player(AKM_RIFLE_FIRE_MODE_SELECTOR, -3.0, "SFX")
	# Reset indexes
	current_weapon_fire_single_index = 0
	current_weapon_dry_fire_single_index = 0


# Plays a 3d sound from the pool at the index provided
func play_sound_3d_from_pool(pool: Array[AudioStreamPlayer3D], index: int) -> void:
	# Get the next available audio player 3d using round-robin
	var audio_player_3d: AudioStreamPlayer3D = pool[index]
	# Reset player if it's still playing
	if audio_player_3d.playing:
		audio_player_3d.stop()
	
	# Slight pitch variation and play sound
	audio_player_3d.pitch_scale = randf_range(0.95, 1.05)  
	audio_player_3d.play()
	
	# NOTE the index update is handled in the function that calls this one


func create_single_audio_player_3d(stream: AudioStream, volume_db: float, max_distance: float, bus: String) -> AudioStreamPlayer3D:
	var audio_player_3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio_player_3d.stream = stream
	audio_player_3d.volume_db = volume_db
	audio_player_3d.max_distance = max_distance
	audio_player_3d.bus = bus
	add_child(audio_player_3d)
	return audio_player_3d


func create_single_audio_player(stream: AudioStream, volume_db: float, bus: String) -> AudioStreamPlayer:
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	audio_player.bus = bus
	add_child(audio_player)
	return audio_player


func play_weapon_fire_single() -> void:
	# Check if we have ammo to fire
	if player.player_equipment.can_fire_weapon():
		_play_weapon_fire_single()
	else:
		_play_weapon_dry_fire_single()


func _play_weapon_fire_single() -> void:
	play_sound_3d_from_pool(current_weapon_fire_single_audio_pool, current_weapon_fire_single_index)
	current_weapon_fire_single_index = (current_weapon_fire_single_index + 1) % POOL_SIZE


func _play_weapon_dry_fire_single() -> void:
	play_sound_3d_from_pool(current_weapon_dry_fire_single_audio_pool, current_weapon_dry_fire_single_index)
	current_weapon_dry_fire_single_index = (current_weapon_dry_fire_single_index + 1) % POOL_SIZE


func play_weapon_remove_magazine() -> void:
	if remove_magazine_audio_player_3d.playing:
		return # Don't interrupt ongoing sound
	
	remove_magazine_audio_player_3d.pitch_scale = randf_range(0.95, 1.05)
	remove_magazine_audio_player_3d.play()


func play_weapon_insert_magazine() -> void:
	if insert_magazine_audio_player_3d.playing:
		return # Don't interrupt ongoing sound
	
	insert_magazine_audio_player_3d.pitch_scale = randf_range(0.95, 1.05)
	insert_magazine_audio_player_3d.play()


func play_weapon_charging_handle() -> void:
	if charging_handle_audio_player_3d.playing:
		return # Don't interrupt ongoing sound
	
	charging_handle_audio_player_3d.pitch_scale = randf_range(0.98, 1.02)
	charging_handle_audio_player_3d.play()


func play_weapon_fire_mode_selector() -> void:
	if fire_mode_selector_audio_player.playing:
		return # Don't interrupt ongoing sound
	
	fire_mode_selector_audio_player.pitch_scale = randf_range(0.95, 1.05)
	fire_mode_selector_audio_player.play()
