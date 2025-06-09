extends Node
class_name PlayerAnimator


# Preloading scripts
const Player := preload("res://objects/character/player/player.gd")

var player: Player = null # Our parent node
var animation_player: AnimationPlayer

# Character locomotion
var locomotion: Dictionary[String, Dictionary] # Depends on the gender of this character
var female_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "female/female_idle", play_rate = 1.0},
	"walk": {animation = "female/female_walk", play_rate = 0.95},
	"jog": {animation = "female/female_run", play_rate = 0.70},
	"run": {animation = "female/female_run", play_rate = 0.8}
}
var male_locomotion: Dictionary[String, Dictionary] = {
	"idle": {animation = "male/male_idle", play_rate = 1.0},
	"walk": {animation = "male/male_walk", play_rate = 1.1},
	"jog": {animation = "male/male_run", play_rate = 0.75},
	"run": {animation = "male/male_run", play_rate = 0.9}
}


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	player = get_parent()
	
	# Switch our locomotion string depending on our player's gender
	locomotion = male_locomotion if player.gender == "male" else female_locomotion
	animation_player = player.find_child("AnimationPlayer", true, false)
	
	_setup_animation_blend_time()


# Helper function to properly setup animation blend times
func _setup_animation_blend_time() -> void:
	if not animation_player:
		push_error("AnimationPlayer not set")
		return
	
	# Blend female locomotion animations
	animation_player.set_blend_time("female/female_idle", "female/female_walk", 0.2)
	animation_player.set_blend_time("female/female_idle", "female/female_run", 0.1)
	animation_player.set_blend_time("female/female_walk", "female/female_idle", 0.15)
	animation_player.set_blend_time("female/female_walk", "female/female_run", 0.15)
	animation_player.set_blend_time("female/female_run", "female/female_idle", 0.15)
	animation_player.set_blend_time("female/female_run", "female/female_walk", 0.15)
	
	# Blend male locomotion animations
	animation_player.set_blend_time("male/male_idle", "male/male_walk", 0.2)
	animation_player.set_blend_time("male/male_idle", "male/male_run", 0.1)
	animation_player.set_blend_time("male/male_walk", "male/male_idle", 0.15)
	animation_player.set_blend_time("male/male_walk", "male/male_run", 0.15)
	animation_player.set_blend_time("male/male_run", "male/male_idle", 0.15)
	animation_player.set_blend_time("male/male_run", "male/male_walk", 0.15)


# Plays and awaits until the animation ends, if found
func play_animation_and_await(animation_name: String) -> void:
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		await animation_player.animation_finished # Wait for it


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
