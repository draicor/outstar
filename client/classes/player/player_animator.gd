extends Node
class_name PlayerAnimator


# Internal variables
var player: Player = null # Our parent node
var animation_player: AnimationPlayer # Our player's AnimationPlayer

# Character locomotion
var locomotion: Dictionary[String, Dictionary] # Depends on the gender of this character
# UNARMED
var unarmed_female_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "unarmed/unarmed_female_idle", play_rate = 1.0},
	"walk": {animation = "unarmed/unarmed_female_walk", play_rate = 1.35},
	"jog": {animation = "unarmed/unarmed_female_jog", play_rate = 1.2},
	"run": {animation = "unarmed/unarmed_run", play_rate = 1.0}
}
var unarmed_male_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "unarmed/unarmed_male_idle", play_rate = 1.0},
	"walk": {animation = "unarmed/unarmed_male_walk", play_rate = 1.35},
	"jog": {animation = "unarmed/unarmed_male_jog", play_rate = 1.2},
	"run": {animation = "unarmed/unarmed_run", play_rate = 1.0}
}
var unarmed_crouch_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "unarmed/unarmed_crouch_idle", play_rate = 1.0},
	"walk": {animation = "unarmed/unarmed_crouch_walk", play_rate = 1.0},
}
# RIFLE
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
var rifle_crouch_down_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "rifle/rifle_crouch_down_idle", play_rate = 1.0},
}
var rifle_crouch_aim_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "rifle/rifle_crouch_aim_idle", play_rate = 1.0},
}
# SHOTGUN
var shotgun_down_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "shotgun/shotgun_down_idle", play_rate = 1.0},
	"walk": {animation = "shotgun/shotgun_down_walk", play_rate = 1.15},
	"jog": {animation = "shotgun/shotgun_down_jog", play_rate = 0.9},
	"run": {animation = "shotgun/shotgun_down_run", play_rate = 0.65},
}
var shotgun_aim_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "shotgun/shotgun_aim_idle", play_rate = 1.0},
	"walk": {animation = "shotgun/shotgun_aim_walk", play_rate = 1.0},
}
var shotgun_crouch_down_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "shotgun/shotgun_crouch_down_idle", play_rate = 1.0},
	"walk": {animation = "shotgun/shotgun_crouch_down_walk", play_rate = 1.0},
}
var shotgun_crouch_aim_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "shotgun/shotgun_crouch_aim_idle", play_rate = 1.0},
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
	# RIFLE
	"rifle/rifle_aim_fire_single_fast": [
		{"time": 0.05, "method": "_call_player_audio_method", "args": ["play_weapon_fire_single"]}, # Has to fire BEFORE decrement ammo
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["weapon_fire"]},
	],
	"rifle/rifle_crouch_aim_fire_single_low_recoil": [
		{"time": 0.05, "method": "_call_player_audio_method", "args": ["play_weapon_fire_single"]}, # Has to fire BEFORE decrement ammo
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["weapon_fire"]},
	],
	"rifle/rifle_aim_reload_slow": [
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
		{"time": 0.5, "method": "_call_player_audio_method", "args": ["play_weapon_remove_magazine"]},
		{"time": 1.05, "method": "_call_player_audio_method", "args": ["play_weapon_insert_magazine"]},
		{"time": 1.42, "method": "_call_player_audio_method", "args": ["play_weapon_charging_handle"]},
		{"time": 1.8, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"rifle/rifle_aim_reload_fast": [
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
		{"time": 0.5, "method": "_call_player_audio_method", "args": ["play_weapon_remove_magazine"]},
		{"time": 1.05, "method": "_call_player_audio_method", "args": ["play_weapon_insert_magazine"]},
		{"time": 1.45, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"rifle/rifle_crouch_aim_reload_slow": [
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
		{"time": 0.35, "method": "_call_player_audio_method", "args": ["play_weapon_remove_magazine"]},
		{"time": 1.9, "method": "_call_player_audio_method", "args": ["play_weapon_insert_magazine"]},
		{"time": 2.95, "method": "_call_player_audio_method", "args": ["play_weapon_charging_handle"]},
		{"time": 4.1, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"rifle/rifle_crouch_aim_reload_fast": [
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
		{"time": 0.35, "method": "_call_player_audio_method", "args": ["play_weapon_remove_magazine"]},
		{"time": 1.9, "method": "_call_player_audio_method", "args": ["play_weapon_insert_magazine"]},
		{"time": 3.55, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"rifle/rifle_equip": [
		{"time": 0.95, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"rifle/rifle_unequip": [
		{"time": 0.0, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
	],
	# SHOTGUN
	"shotgun/shotgun_aim_fire": [
		{"time": 0.05, "method": "_call_player_audio_method", "args": ["play_weapon_fire_single"]}, # Has to fire BEFORE decrement ammo
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["weapon_fire"]},
	],
	"shotgun/shotgun_aim_pump": [
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
		{"time": 0.15, "method": "_call_player_audio_method", "args": ["play_weapon_shotgun_cock"]},
		{"time": 0.6, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"shotgun/shotgun_crouch_aim_fire": [
		{"time": 0.05, "method": "_call_player_audio_method", "args": ["play_weapon_fire_single"]}, # Has to fire BEFORE decrement ammo
		{"time": 0.1, "method": "_call_player_equipment_method", "args": ["weapon_fire"]},
	],
	"shotgun/shotgun_crouch_aim_pump": [
		{"time": 0.2, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
		{"time": 0.3, "method": "_call_player_audio_method", "args": ["play_weapon_shotgun_cock"]},
		{"time": 0.7, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"shotgun/shotgun_aim_reload_start": [
		{"time": 0.04, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
	],
	"shotgun/shotgun_aim_reload_shell": [
		{"time": 0.13, "method": "_call_player_audio_method", "args": ["play_weapon_load_bullet"]},
	],
	"shotgun/shotgun_aim_reload_end": [
		{"time": 0.4, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
	"shotgun/shotgun_crouch_aim_reload_start": [
		{"time": 0.04, "method": "_call_player_equipment_method", "args": ["disable_left_hand_ik"]},
	],
	"shotgun/shotgun_crouch_aim_reload_shell": [
		{"time": 0.13, "method": "_call_player_audio_method", "args": ["play_weapon_load_bullet"]},
	],
	"shotgun/shotgun_crouch_aim_reload_end": [
		{"time": 0.4, "method": "_call_player_equipment_method", "args": ["enable_left_hand_ik"]},
	],
}

# All the actions we can call and their asociated animations
var weapon_animations: Dictionary[String, Dictionary] = {
	"unarmed": {
		"down_to_crouch_down": {
			animation = "unarmed/unarmed_male_idle_to_unarmed_crouch_idle",
			play_rate = 2.5
		},
		"crouch_down_to_down": {
			animation = "unarmed/unarmed_crouch_idle_to_unarmed_male_idle",
			play_rate = 2.5
		},
		# NOTE: equip and unequip animations for unarmed would just be transitions
	},
	"rifle": {
		"equip": {
			animation = "rifle/rifle_equip",
			play_rate = 1.0
		},
		"unequip": {
			animation = "rifle/rifle_unequip",
			play_rate = 1.0
		},
		"reload_slow": {
			animation = "rifle/rifle_aim_reload_slow",
			play_rate = 0.7
		},
		"reload_fast": {
			animation = "rifle/rifle_aim_reload_fast",
			play_rate = 0.7
		},
		"crouch_reload_slow": {
			animation = "rifle/rifle_crouch_aim_reload_slow",
			play_rate = 1.3
		},
		"crouch_reload_fast": {
			animation = "rifle/rifle_crouch_aim_reload_fast",
			play_rate = 1.3
		},
		"down_to_aim": {
			animation = "rifle/rifle_down_to_rifle_aim",
			play_rate = 3.0
		},
		"aim_to_down": {
			animation = "rifle/rifle_aim_to_rifle_down",
			play_rate = 3.0
		},
		"crouch_down_to_crouch_aim": {
			animation = "rifle/rifle_crouch_down_to_rifle_crouch_aim",
			play_rate = 2.0
		},
		"crouch_aim_to_crouch_down": {
			animation = "rifle/rifle_crouch_aim_to_rifle_crouch_down",
			play_rate = 2.0
		},
		"crouch_aim_to_aim": {
			animation = "rifle/rifle_crouch_aim_to_rifle_aim",
			play_rate = 1.0
		},
		"crouch_down_to_down": {
			animation = "rifle/rifle_crouch_down_to_rifle_down", 
			play_rate = 1.3
		},
		"aim_to_crouch_aim": {
			animation = "rifle/rifle_aim_to_rifle_crouch_aim",
			play_rate = 1.0
		},
		"down_to_crouch_down": {
			animation = "rifle/rifle_down_to_rifle_crouch_down",
			play_rate = 1.3
		},
		"fire_single": {
			animation = "rifle/rifle_aim_fire_single_fast",
			play_rate = 1.0 # Get overriden by each weapon
		},
		"crouch_fire_single": {
			animation = "rifle/rifle_crouch_aim_fire_single_low_recoil",
			play_rate = 1.0  # Get overriden by each weapon
		},
	},
	"shotgun": {
		"equip": {
			animation = "rifle/rifle_equip", # NOTE using rifle equip for now
			play_rate = 1.0
		},
		"unequip": {
			animation = "rifle/rifle_unequip", # NOTE using rifle equip for now
			play_rate = 1.0
		},
		"reload_start": {
			animation = "shotgun/shotgun_aim_reload_start",
			play_rate = 0.9
		},
		"reload_shell": {
			animation = "shotgun/shotgun_aim_reload_shell",
			play_rate = 0.9
		},
		"reload_end": {
			animation = "shotgun/shotgun_aim_reload_end",
			play_rate = 0.9
		},
		"pump": {
			animation = "shotgun/shotgun_aim_pump",
			play_rate = 1.0
		},
		"crouch_reload_start": {
			animation = "shotgun/shotgun_crouch_aim_reload_start",
			play_rate = 0.9
		},
		"crouch_reload_shell": {
			animation = "shotgun/shotgun_crouch_aim_reload_shell",
			play_rate = 0.9
		},
		"crouch_reload_end": {
			animation = "shotgun/shotgun_crouch_aim_reload_end",
			play_rate = 0.9
		},
		"crouch_pump": {
			animation = "shotgun/shotgun_crouch_aim_pump",
			play_rate = 1.0
		},
		"down_to_aim": {
			animation = "shotgun/shotgun_down_to_shotgun_aim",
			play_rate = 3.2
		},
		"aim_to_down": {
			animation = "shotgun/shotgun_aim_to_shotgun_down",
			play_rate = 3.2
		},
		"crouch_down_to_crouch_aim": {
			animation = "shotgun/shotgun_crouch_down_to_shotgun_crouch_aim",
			play_rate = 3.2
		},
		"crouch_aim_to_crouch_down": {
			animation = "shotgun/shotgun_crouch_aim_to_shotgun_crouch_down",
			play_rate = 3.2
		},
		"crouch_aim_to_aim": {
			animation = "shotgun/shotgun_crouch_aim_to_shotgun_aim",
			play_rate = 2.5
		},
		"crouch_down_to_down": {
			animation = "shotgun/shotgun_crouch_down_to_shotgun_down", 
			play_rate = 2.0
		},
		"aim_to_crouch_aim": {
			animation = "shotgun/shotgun_aim_to_shotgun_crouch_aim",
			play_rate = 2.5
		},
		"down_to_crouch_down": {
			animation = "shotgun/shotgun_down_to_shotgun_crouch_down",
			play_rate = 2.0
		},
		"fire_single": {
			animation = "shotgun/shotgun_aim_fire",
			play_rate = 1.0 # Get overriden by each weapon
		},
		"crouch_fire_single": {
			animation = "shotgun/shotgun_crouch_aim_fire",
			play_rate = 1.0  # Get overriden by each weapon
		},
	}
	# Add more weapon types here
}


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	# Wait a single frame to allow time for the other player components to load
	await get_tree().process_frame
	player = get_parent()
	
	# Switch our locomotion depending on our player's gender
	switch_animation_library(player.gender)
	animation_player = player.find_child("AnimationPlayer", true, false)
	
	_setup_animation_blend_times()
	
	# Connect to animation player signals to check every frame to call anim events
	animation_player.connect("animation_started", _on_animation_started)
	animation_player.connect("animation_finished", _on_animation_finished)


# Runs on tick to check for animation_events
func _process(_delta: float) -> void:
	if current_animation != "" and animation_events.has(current_animation):
		check_animation_events()


# Helper function to properly setup animation blend times
func _setup_animation_blend_times() -> void:
	if not animation_player:
		push_error("AnimationPlayer not set")
		return
	
	_setup_unarmed_animation_blend_times()
	_setup_rifle_animation_blend_times()
	_setup_shotgun_animation_blend_times()


# Helper function for unarmed blend times
func _setup_unarmed_animation_blend_times() -> void:
	# Blend female locomotion
	animation_player.set_blend_time("unarmed/unarmed_female_idle", "unarmed/unarmed_female_walk", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_female_idle", "unarmed/unarmed_female_jog", 0.05)
	animation_player.set_blend_time("unarmed/unarmed_female_idle", "unarmed/unarmed_run", 0.05)
	animation_player.set_blend_time("unarmed/unarmed_female_walk", "unarmed/unarmed_female_idle", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_female_walk", "unarmed/unarmed_female_jog", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_female_walk", "unarmed/unarmed_run", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_female_jog", "unarmed/unarmed_female_idle", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_female_jog", "unarmed/unarmed_female_walk", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_female_jog", "unarmed/unarmed_run", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_run", "unarmed/unarmed_female_idle", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_run", "unarmed/unarmed_female_walk", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_run", "unarmed/unarmed_female_jog", 0.2)
	
	# Blend male locomotion
	animation_player.set_blend_time("unarmed/unarmed_male_idle", "unarmed/unarmed_male_walk", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_male_idle", "unarmed/unarmed_male_jog", 0.1)
	animation_player.set_blend_time("unarmed/unarmed_male_idle", "unarmed/unarmed_run", 0.1)
	animation_player.set_blend_time("unarmed/unarmed_male_walk", "unarmed/unarmed_male_idle", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_male_walk", "unarmed/unarmed_male_jog", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_male_walk", "unarmed/unarmed_run", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_male_jog", "unarmed/unarmed_male_idle", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_male_jog", "unarmed/unarmed_male_walk", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_male_jog", "unarmed/unarmed_run", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_run", "unarmed/unarmed_male_idle", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_run", "unarmed/unarmed_male_walk", 0.15)
	animation_player.set_blend_time("unarmed/unarmed_run", "unarmed/unarmed_male_jog", 0.15)
	
	# Blend unarmed crouch locomotion
	animation_player.set_blend_time("unarmed/unarmed_crouch_idle", "unarmed/unarmed_crouch_walk", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_crouch_walk", "unarmed/unarmed_crouch_idle", 0.2)
	
	# Blend crouch transitions
	animation_player.set_blend_time("unarmed/unarmed_male_idle", "unarmed/unarmed_male_idle_to_unarmed_crouch_idle", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_male_idle_to_unarmed_crouch_idle", "unarmed/unarmed_crouch_idle", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_crouch_idle", "unarmed/unarmed_crouch_idle_to_unarmed_male_idle", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_crouch_idle_to_unarmed_male_idle", "unarmed/unarmed_male_idle", 0.2)


# Helper function for rifle blend times
func _setup_rifle_animation_blend_times() -> void:
	# Blend rifle equip
	animation_player.set_blend_time("rifle/rifle_equip", "rifle/rifle_down_idle", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_female_idle", "rifle/rifle_equip", 0.2)
	animation_player.set_blend_time("unarmed/unarmed_male_idle", "rifle/rifle_equip", 0.2)
	
	# Blend rifle unequip
	animation_player.set_blend_time("rifle/rifle_down_idle", "rifle/rifle_unequip", 0.2)
	animation_player.set_blend_time("rifle/rifle_unequip", "unarmed/unarmed_female_idle", 0.2)
	animation_player.set_blend_time("rifle/rifle_unequip", "unarmed/unarmed_male_idle", 0.2)
	
	# Blend rifle down to rifle aim
	animation_player.set_blend_time("rifle/rifle_down_idle", "rifle/rifle_down_to_rifle_aim", 0.2)
	animation_player.set_blend_time("rifle/rifle_down_to_rifle_aim", "rifle/rifle_aim_idle", 0.2)
	
	# Blend rifle aim to rifle down
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_to_rifle_down", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_to_rifle_down", "rifle/rifle_down_idle", 0.2)
	
	# Blend rifle fire single fast
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_fire_single_fast", 0.4)
	animation_player.set_blend_time("rifle/rifle_aim_fire_single_fast", "rifle/rifle_aim_fire_single_fast", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_fire_single_fast", "rifle/rifle_aim_walk", 0.2)
	animation_player.set_blend_time("rifle/rifle_aim_fire_single_fast", "rifle/rifle_aim_jog", 0.2)
	# Blend rifle reload
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_reload_fast", 0.1)
	animation_player.set_blend_time("rifle/rifle_aim_reload_fast", "rifle/rifle_aim_idle", 0.1)
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_reload_slow", 0.1)
	animation_player.set_blend_time("rifle/rifle_aim_reload_slow", "rifle/rifle_aim_idle", 0.1)
	
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
	
	# Blend rifle crouch down to rifle crouch aim
	animation_player.set_blend_time("rifle/rifle_crouch_down_idle", "rifle/rifle_crouch_down_to_rifle_crouch_aim", 0.1)
	animation_player.set_blend_time("rifle/rifle_crouch_down_to_rifle_crouch_aim", "rifle/rifle_crouch_aim_idle", 0.1)
	# Blend rifle crouch aim to rifle crouch down
	animation_player.set_blend_time("rifle/rifle_crouch_aim_idle", "rifle/rifle_crouch_aim_to_rifle_crouch_down", 0.1)
	animation_player.set_blend_time("rifle/rifle_crouch_aim_to_rifle_crouch_down", "rifle/rifle_crouch_down_idle", 0.1)
	
	# Blend rifle aim to rifle crouch aim
	animation_player.set_blend_time("rifle/rifle_aim_idle", "rifle/rifle_aim_to_rifle_crouch_aim", 0.1)
	animation_player.set_blend_time("rifle/rifle_aim_to_rifle_crouch_aim", "rifle/rifle_crouch_aim_idle", 0.1)
	# Blend rifle crouch aim to rifle aim
	animation_player.set_blend_time("rifle/rifle_crouch_aim_idle", "rifle/rifle_crouch_aim_to_rifle_aim", 0.1)
	animation_player.set_blend_time("rifle/rifle_crouch_aim_to_rifle_aim", "rifle/rifle_aim_idle", 0.1)
	
	# Blend rifle down to rifle crouch down
	animation_player.set_blend_time("rifle/rifle_down_idle", "rifle/rifle_down_to_rifle_crouch_down", 0.1)
	animation_player.set_blend_time("rifle/rifle_down_to_rifle_crouch_down", "rifle/rifle_crouch_down_idle", 0.1)
	# Blend rifle crouch down to rifle down
	animation_player.set_blend_time("rifle/rifle_crouch_down_idle", "rifle/rifle_crouch_down_to_rifle_down", 0.1)
	animation_player.set_blend_time("rifle/rifle_crouch_down_to_rifle_down", "rifle/rifle_down_idle", 0.1)
	
	# Blend rifle crouch firing
	animation_player.set_blend_time("rifle/rifle_crouch_aim_idle", "rifle/rifle_crouch_aim_fire_single_low_recoil", 0.4)
	animation_player.set_blend_time("rifle/rifle_crouch_aim_fire_single_low_recoil", "rifle/rifle_crouch_aim_fire_single_low_recoil", 0.2)
	# Blend rifle crouch reload
	animation_player.set_blend_time("rifle/rifle_crouch_aim_idle", "rifle/rifle_crouch_aim_reload_fast", 0.1)
	animation_player.set_blend_time("rifle/rifle_crouch_aim_reload_fast", "rifle/rifle_crouch_aim_idle", 0.1)
	animation_player.set_blend_time("rifle/rifle_crouch_aim_idle", "rifle/rifle_crouch_aim_reload_slow", 0.1)
	animation_player.set_blend_time("rifle/rifle_crouch_aim_reload_slow", "rifle/rifle_crouch_aim_idle", 0.1)


# Helper function for shotgun blend times
func _setup_shotgun_animation_blend_times() -> void:
	# Blend shotgun equip
	animation_player.set_blend_time("rifle/rifle_equip", "shotgun/shotgun_down_idle", 0.4)
	
	# Blend shotgun unequip
	animation_player.set_blend_time("shotgun/shotgun_down_idle", "rifle/rifle_unequip", 0.2)
	
	# Blend shotgun down locomotion
	animation_player.set_blend_time("shotgun/shotgun_down_idle", "shotgun/shotgun_down_walk", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_idle", "shotgun/shotgun_down_jog", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_idle", "shotgun/shotgun_down_run", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_walk", "shotgun/shotgun_down_idle", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_walk", "shotgun/shotgun_down_jog", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_walk", "shotgun/shotgun_down_run", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_jog", "shotgun/shotgun_down_idle", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_jog", "shotgun/shotgun_down_walk", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_jog", "shotgun/shotgun_down_run", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_run", "shotgun/shotgun_down_idle", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_run", "shotgun/shotgun_down_walk", 0.3)
	animation_player.set_blend_time("shotgun/shotgun_down_run", "shotgun/shotgun_down_jog", 0.2)
	
	# Blend shotgun aim locomotion
	animation_player.set_blend_time("shotgun/shotgun_aim_idle", "shotgun/shotgun_aim_walk", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_aim_walk", "shotgun/shotgun_aim_idle", 0.2)
	
	# Blend shotgun down and aim locomotions (transitions between down and aim states)
	animation_player.set_blend_time("shotgun/shotgun_aim_idle", "shotgun/shotgun_down_run", 0.25)
	animation_player.set_blend_time("shotgun/shotgun_aim_walk", "shotgun/shotgun_down_run", 0.3)
	animation_player.set_blend_time("shotgun/shotgun_down_run", "shotgun/shotgun_aim_idle", 0.15)
	animation_player.set_blend_time("shotgun/shotgun_down_run", "shotgun/shotgun_aim_walk", 0.2)
	
	# Blend shotgun down to aim and aim to down transitions
	animation_player.set_blend_time("shotgun/shotgun_down_idle", "shotgun/shotgun_down_to_shotgun_aim", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_down_to_shotgun_aim", "shotgun/shotgun_aim_idle", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_aim_idle", "shotgun/shotgun_aim_to_shotgun_down", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_aim_to_shotgun_down", "shotgun/shotgun_down_idle", 0.2)
	
	# Blend shotgun crouch down to crouch aim and back
	animation_player.set_blend_time("shotgun/shotgun_crouch_down_idle", "shotgun/shotgun_crouch_down_to_shotgun_crouch_aim", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_down_to_shotgun_crouch_aim", "shotgun/shotgun_crouch_aim_idle", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_idle", "shotgun/shotgun_crouch_aim_to_shotgun_crouch_down", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_to_shotgun_crouch_down", "shotgun/shotgun_crouch_down_idle", 0.1)
	
	# Blend shotgun aim to crouch aim and back
	animation_player.set_blend_time("shotgun/shotgun_aim_idle", "shotgun/shotgun_aim_to_shotgun_crouch_aim", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_aim_to_shotgun_crouch_aim", "shotgun/shotgun_crouch_aim_idle", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_idle", "shotgun/shotgun_crouch_aim_to_shotgun_aim", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_to_shotgun_aim", "shotgun/shotgun_aim_idle", 0.1)
	
	# Blend shotgun down to crouch down and back
	animation_player.set_blend_time("shotgun/shotgun_down_idle", "shotgun/shotgun_down_to_shotgun_crouch_down", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_down_to_shotgun_crouch_down", "shotgun/shotgun_crouch_down_idle", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_down_idle", "shotgun/shotgun_crouch_down_to_shotgun_down", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_down_to_shotgun_down", "shotgun/shotgun_down_idle", 0.1)
	
	# Blend shotgun fire
	animation_player.set_blend_time("shotgun/shotgun_aim_idle", "shotgun/shotgun_aim_fire", 0.4)
	animation_player.set_blend_time("shotgun/shotgun_aim_fire", "shotgun/shotgun_aim_fire", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_aim_fire", "shotgun/shotgun_aim_walk", 0.2)
	
	# Blend shotgun pump
	animation_player.set_blend_time("shotgun/shotgun_aim_pump", "shotgun/shotgun_aim_fire", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_aim_fire", "shotgun/shotgun_aim_pump", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_aim_pump", "shotgun/shotgun_aim_idle", 0.2)
	
	# Blend shotgun crouch firing
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_idle", "shotgun/shotgun_crouch_aim_fire", 0.4)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_fire", "shotgun/shotgun_crouch_aim_fire", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_fire", "shotgun/shotgun_crouch_aim_idle", 0.2)
	
	# Blend shotgun pump
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_pump", "shotgun/shotgun_crouch_aim_fire", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_fire", "shotgun/shotgun_crouch_aim_pump", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_pump", "shotgun/shotgun_crouch_aim_idle", 0.2)
	
	# Blend shotgun crouch down locomotion
	animation_player.set_blend_time("shotgun/shotgun_crouch_down_idle", "shotgun/shotgun_crouch_down_walk", 0.2)
	animation_player.set_blend_time("shotgun/shotgun_crouch_down_walk", "shotgun/shotgun_crouch_down_idle", 0.2)
	
	 # Blend for reload animations
	animation_player.set_blend_time("shotgun/shotgun_aim_idle", "shotgun/shotgun_aim_reload_start", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_aim_reload_start", "shotgun/shotgun_aim_reload_shell", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_aim_reload_shell", "shotgun/shotgun_aim_reload_shell", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_aim_reload_shell", "shotgun/shotgun_aim_reload_end", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_aim_reload_end", "shotgun/shotgun_aim_idle", 0.1)

	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_idle", "shotgun/shotgun_crouch_aim_reload_start", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_reload_start", "shotgun/shotgun_crouch_aim_reload_shell", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_reload_shell", "shotgun/shotgun_crouch_aim_reload_shell", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_reload_shell", "shotgun/shotgun_crouch_aim_reload_end", 0.1)
	animation_player.set_blend_time("shotgun/shotgun_crouch_aim_reload_end", "shotgun/shotgun_crouch_aim_idle", 0.1)


# Plays and awaits until the animation ends, if found
func play_animation_and_await(animation_name: String, play_rate: float = 1.0) -> void:
	# Only set for local player since this blocks packet processing
	if player.is_local_player:
		player.is_busy = true
	
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		animation_player.speed_scale = play_rate
		
		# Wait for the animation to finish before proceding
		# NOTE this requires checking against player.is_busy and
		# awaiting play_animation_and_await() too for it to work
		await animation_player.animation_finished
	else:
		push_error(animation_name, " animation not found.")
	
	if player.is_local_player:
		player.is_busy = false


# Used to switch the current animation state
func switch_animation(anim_state: String) -> void:
	# If this state is not valid, ignore
	if not locomotion.has(anim_state):
		return
	
	var settings = locomotion[anim_state]
	var anim_name = settings.animation
	
	# If we are already playing this animation, ignore
	if animation_player.current_animation == anim_name:
		# Update speed if it changed (like running to jog state using the same anim)
		animation_player.speed_scale = settings.play_rate
		return
	
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		animation_player.speed_scale = settings.play_rate
	
		# Only emit this signal for my own character (I don't remember why)
		if player.is_local_player:
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
		unarmed_female_locomotion: return "unarmed_idle"
		unarmed_male_locomotion: return "unarmed_idle"
		unarmed_crouch_locomotion: return "unarmed_crouch_idle"
		rifle_down_locomotion: return "rifle_down_idle"
		rifle_crouch_down_locomotion: return "rifle_crouch_down_idle"
		shotgun_down_locomotion: return "shotgun_down_idle"
		shotgun_crouch_down_locomotion: return "shotgun_crouch_down_idle"
		_:
			return ""


# Returns the aim state name
func get_aim_state_name() -> String:
	match locomotion:
		rifle_aim_locomotion: return "rifle_aim_idle"
		rifle_crouch_aim_locomotion: return "rifle_crouch_aim_idle"
		shotgun_aim_locomotion: return "shotgun_aim_idle"
		shotgun_crouch_aim_locomotion: return "shotgun_crouch_aim_idle"
		_:
			push_error("Error in get_aim_state_name, can't find ", locomotion)
			return get_idle_state_name()


# Returns the appropiate animation library based on weapon type and gender
func get_animation_library(weapon_type: String, gender: String) -> String:
	match weapon_type:
		"rifle":
			return "rifle_down"
		"shotgun":
			return "shotgun_down"
		_:
			return gender # Fallback to gender animation


# Helper function to update our locomotion dictionary based on equipped items or gender
func switch_animation_library(animation_library: String) -> void:
	match animation_library:
		"male": locomotion = unarmed_male_locomotion
		"female": locomotion = unarmed_female_locomotion
		"unarmed_crouch": locomotion = unarmed_crouch_locomotion
		"rifle_down": locomotion = rifle_down_locomotion
		"rifle_aim": locomotion = rifle_aim_locomotion
		"rifle_crouch_down": locomotion = rifle_crouch_down_locomotion
		"rifle_crouch_aim": locomotion = rifle_crouch_aim_locomotion
		"shotgun_down": locomotion = shotgun_down_locomotion
		"shotgun_aim": locomotion = shotgun_aim_locomotion
		"shotgun_crouch_down": locomotion = shotgun_crouch_down_locomotion
		"shotgun_crouch_aim": locomotion = shotgun_crouch_aim_locomotion
		_: push_error("Library name not valid")


# Connects to the player audio class and uses it to call a function in it
func _call_player_audio_method(method_name: String) -> void:
	if player.player_audio and player.player_audio.has_method(method_name):
		player.player_audio.call(method_name)


# Connects to the player equipment class and uses it to call a function in it
func _call_player_equipment_method(method_name: String) -> void:
	if player.player_equipment and player.player_equipment.has_method(method_name):
		player.player_equipment.call(method_name)


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


# Looks into our weapon animations dictionary for this animation, if it exists, return the animation name and play rate
func get_weapon_animation(animation_type: String, weapon_type: String) -> Dictionary:
	if weapon_animations.has(weapon_type) and weapon_animations[weapon_type].has(animation_type):
		return weapon_animations[weapon_type][animation_type]
	return {}


# Plays the weapon animation if found within our weapon dictionary
func play_weapon_animation_and_await(animation_type: String, weapon_type: String, custom_speed: float = 1.0) -> void:
	var anim = get_weapon_animation(animation_type, weapon_type)
	if anim.is_empty():
		push_error("[%s, %s] not found." % [weapon_type, animation_type])
		return
	
	var animation_name: String = anim.animation
	var animation_play_rate: float = anim.play_rate
	
	# If the animation name is valid
	if animation_name != "":
		# If we passed a different speed here, use that custom speed, else use the default one
		if custom_speed != 1.0:
			animation_play_rate = custom_speed
		
		await play_animation_and_await(animation_name, animation_play_rate)
