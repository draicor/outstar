extends Node
class_name PlayerAnimator


# Internal variables
var player: Player = null # Our parent node
var animation_player: AnimationPlayer # Our player's AnimationPlayer
var player_audio: PlayerAudio # Used to call functions directly from the audio class
var player_equipment: PlayerEquipment # Used to call functions directly from equipment class

# Character locomotion
var locomotion: Dictionary[String, Dictionary] # Depends on the gender of this character
var female_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "female/female_idle", play_rate = 1.0},
	"walk": {animation = "female/female_walk", play_rate = 0.95},
	"jog": {animation = "female/female_run", play_rate = 0.7},
	"run": {animation = "female/female_run", play_rate = 0.8}
}
var male_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "male/male_idle", play_rate = 1.0},
	"walk": {animation = "male/male_walk", play_rate = 1.1},
	"jog": {animation = "male/male_run", play_rate = 0.7},
	"run": {animation = "male/male_run", play_rate = 0.9}
}
var rifle_down_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "rifle/rifle_down_idle", play_rate = 1.0},
	"walk": {animation = "rifle/rifle_down_walk", play_rate = 1.25},
	"jog": {animation = "rifle/rifle_down_run", play_rate = 0.8},
	"run": {animation = "rifle/rifle_down_run", play_rate = 1.1},
}
var rifle_aim_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "rifle/rifle_aim_idle", play_rate = 1.0},
	"walk": {animation = "rifle/rifle_aim_walk", play_rate = 1.1},
	"jog": {animation = "rifle/rifle_aim_jog", play_rate = 1.0},
	"run": {animation = "rifle/rifle_down_run", play_rate = 1.1},
}

# Animation events (timing for each animation)
var current_animation: String = ""
var animation_start_time: float = 0.0
var triggered_events: Dictionary = {}

# method: the function name within player_animator.gd we are going to call
# args: parameters we want to pass to the function we are calling above
# NOTE for sounds, we are using method to call a function in player_animator.gd,
# and the parameter of this function is the name of the method in player_audio.gd,
# the downside of this is that we can't pass an argument, so we must create a unique,
# sound method for every different sound we want to call from player_audio.gd
var animation_events: Dictionary[String, Array] = {
	"rifle/rifle_aim_fire_single_fast": [
		{"time": 0.05, "method": "_call_player_audio_method", "args": ["play_projectile_rifle_fire_single"]}, # Has to fire BEFORE decrement ammo
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["weapon_fire_single"]},
	],
	"rifle/rifle_aim_reload_fast": [
		{"time": 0.7, "method": "_call_player_audio_method", "args": ["play_projectile_rifle_remove_magazine"]},
		{"time": 1.6, "method": "_call_player_audio_method", "args": ["play_projectile_rifle_insert_magazine"]},
		{"time": 2.1, "method": "_call_player_audio_method", "args": ["play_projectile_rifle_charging_handle"]},
	]
}


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	player = get_parent()
	
	# Fetch the PlayerAudio from our parent
	player_audio = player.find_child("PlayerAudio", true, false)
	if not player_audio:
		push_error("Player Audio not available")
	
	# Fetch the PlayerEquiment from our parent
	player_equipment = player.find_child("PlayerEquipment", true, false)
	if not player_equipment:
		push_error("Player Equipment not available")
	
	# CAUTION Modify this to keep in mind the equipped weapon in our DB too!
	# Switch our locomotion depending on our player's gender
	switch_animation_library(player.gender)
	animation_player = player.find_child("AnimationPlayer", true, false)
	
	_setup_animation_blend_time()
	
	# Connect to animation player signals to check every frame to call anim events
	animation_player.connect("animation_started", _on_animation_started)
	animation_player.connect("animation_finished", _on_animation_finished)


# Runs on tick to check for animation_events
func _process(_delta: float) -> void:
	if current_animation != "" and animation_events.has(current_animation):
		check_animation_events()


# Helper function to properly setup animation blend times
func _setup_animation_blend_time() -> void:
	if not animation_player:
		push_error("AnimationPlayer not set")
		return
	
	# Blend female locomotion
	animation_player.set_blend_time("female/female_idle", "female/female_walk", 0.2)
	animation_player.set_blend_time("female/female_idle", "female/female_run", 0.05)
	animation_player.set_blend_time("female/female_walk", "female/female_idle", 0.15)
	animation_player.set_blend_time("female/female_walk", "female/female_run", 0.15)
	animation_player.set_blend_time("female/female_run", "female/female_idle", 0.2)
	animation_player.set_blend_time("female/female_run", "female/female_walk", 0.2)
	
	# Blend male locomotion
	animation_player.set_blend_time("male/male_idle", "male/male_walk", 0.2)
	animation_player.set_blend_time("male/male_idle", "male/male_run", 0.1)
	animation_player.set_blend_time("male/male_walk", "male/male_idle", 0.15)
	animation_player.set_blend_time("male/male_walk", "male/male_run", 0.15)
	animation_player.set_blend_time("male/male_run", "male/male_idle", 0.15)
	animation_player.set_blend_time("male/male_run", "male/male_walk", 0.15)
	
	# Blend rifle equip
	animation_player.set_blend_time("rifle/rifle_equip", "rifle/rifle_down_idle", 0.2)
	animation_player.set_blend_time("female/female_idle", "rifle/rifle_equip", 0.2)
	animation_player.set_blend_time("male/male_idle", "rifle/rifle_equip", 0.2)
	
	# Blend rifle unequip
	animation_player.set_blend_time("rifle/rifle_down_idle", "rifle/rifle_unequip", 0.2)
	animation_player.set_blend_time("rifle/rifle_unequip", "female/female_idle", 0.2)
	animation_player.set_blend_time("rifle/rifle_unequip", "male/male_idle", 0.2)
	
	# Blend rifle down to rifle aim
	animation_player.set_blend_time("rifle/rifle_down_idle", "rifle/rifle_down_to_aim", 0.2)
	animation_player.set_blend_time("rifle/rifle_down_to_aim", "rifle/rifle_aim_idle", 0.2)
	
	# Blend rifle aim to rifle down
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_to_down", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_to_down", "rifle/rifle_down_idle", 0.2)
	
	# Blend rifle fire single fast
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_fire_single_fast", 0.4)
	animation_player.set_blend_time("rifle/rifle_aim_fire_single_fast", "rifle/rifle_aim_fire_single_fast", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_fire_single_fast", "rifle/rifle_aim_walk", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_fire_single_fast", "rifle/rifle_aim_jog", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_fire_single_fast", "rifle/rifle_aim_run", 0.2)
	
	# Blend rifle down locomotion
	animation_player.set_blend_time("rifle/rifle_down_idle", "rifle/rifle_down_walk", 0.2)
	animation_player.set_blend_time("rifle/rifle_down_idle", "rifle/rifle_down_run", 0.25)
	animation_player.set_blend_time("rifle/rifle_down_walk", "rifle/rifle_down_idle", 0.2)
	animation_player.set_blend_time("rifle/rifle_down_walk", "rifle/rifle_down_run", 0.25)
	animation_player.set_blend_time("rifle/rifle_down_run", "rifle/rifle_down_idle", 0.2)
	animation_player.set_blend_time("rifle/rifle_down_run", "rifle/rifle_down_walk", 0.3)
	
	# Blend rifle aim locomotion
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_walk", 0.1)
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_jog", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_walk", "rifle/rifle_aim_idle", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_walk", "rifle/rifle_aim_jog", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_jog", "rifle/rifle_aim_idle", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_jog", "rifle/rifle_aim_walk", 0.2)
	
	# Blend rifle down and rifle aim locomotions
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_down_run", 0.25)
	animation_player.set_blend_time("rifle/rifle_aim_walk", "rifle/rifle_down_run", 0.3)
	animation_player.set_blend_time("rifle/rifle_aim_jog", "rifle/rifle_down_run", 0.15)
	animation_player.set_blend_time("rifle/rifle_down_run", "rifle/rifle_aim_idle", 0.15)
	animation_player.set_blend_time("rifle/rifle_down_run", "rifle/rifle_aim_walk", 0.2)
	animation_player.set_blend_time("rifle/rifle_down_run", "rifle/rifle_aim_jog", 0.2)


# Plays and awaits until the animation ends, if found
func play_animation_and_await(animation_name: String, play_rate: float = 1.0) -> void:
	if animation_player.has_animation(animation_name):
		# Make our player busy so he can't do anything else while doing this
		player.is_busy = true
		
		animation_player.play(animation_name)
		animation_player.speed_scale = play_rate
		# Wait for the animation to finish before proceding
		# NOTE this requires checking against player.is_busy and
		# awaiting play_animation_and_await() too for it to work
		await animation_player.animation_finished
		
		player.is_busy = false
	else:
		print(animation_name, " animation not found.")


# Used to switch the current animation state
func switch_animation(anim_state: String) -> void:
	if not locomotion.has(anim_state):
		return
	
	var settings = locomotion[anim_state]
	var anim_name = settings.animation
	
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		animation_player.speed_scale = settings.play_rate
	
		# Only emit this signal for my own character
		if player.my_player_character:
			Signals.player_locomotion_changed.emit(anim_state)


# Helper function to update our locomotion animation based on the cells to traverse
func update_locomotion_animation(cells_to_move: int) -> void:
	# Determine animation based on player_speed
	var anim_state: String
	match cells_to_move:
		1: anim_state = "walk"
		2: anim_state = "jog"
		_: anim_state = "run"
	
	switch_animation(anim_state)


# Returns the idle state name 
func get_idle_state_name() -> String:
	match locomotion:
		rifle_down_locomotion: return "rifle_down_idle"
		rifle_aim_locomotion: return "rifle_aim_idle"
		_: return "idle"


# Helper function to update our locomotion dictionary based on equipped items or gender
func switch_animation_library(animation_library: String) -> void:
	match animation_library:
		"male": locomotion = male_locomotion
		"female": locomotion = female_locomotion
		"rifle_down": locomotion = rifle_down_locomotion
		"rifle_aim": locomotion = rifle_aim_locomotion
		_: push_error("Library name not valid")


# Connects to the player audio class and uses it to call a function in it
func _call_player_audio_method(method_name: String) -> void:
	if player_audio and player_audio.has_method(method_name):
		player_audio.call(method_name)


# Connects to the player equipment class and uses it to call a function in it
func _call_player_equipment_method(method_name: String) -> void:
	if player_equipment and player_equipment.has_method(method_name):
		player_equipment.call(method_name)


# Connected to the animation player signal
func _on_animation_started(anim_name: String) -> void:
	current_animation = anim_name
	animation_start_time = Time.get_ticks_msec()
	triggered_events.clear()


# Connected to the animation player signal
func _on_animation_finished(_anim_name: String) -> void:
	current_animation = ""


# Used to trigger method calls at a specific time in our animations
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
