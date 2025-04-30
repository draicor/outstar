extends Control

@export var walk_texture: CompressedTexture2D = preload("res://assets/icons/icon_walk.png")
@export var jog_texture: CompressedTexture2D = preload("res://assets/icons/icon_jog.png")
@export var run_texture: CompressedTexture2D = preload("res://assets/icons/icon_run.png")

@onready var change_move_speed: Button = $ChangeMoveSpeed

func _ready() -> void:
	change_move_speed.icon = run_texture

# Request the server to change the movement speed
func _on_change_move_speed_button_down() -> void:
	# Only send the packet to update our speed if we are IDLE
	if GameManager.player_character.current_animation == GameManager.player_character.ASM.IDLE:
		if GameManager.player_character.player_speed == 1:
			change_move_speed.icon = jog_texture
		elif GameManager.player_character.player_speed == 2:
			change_move_speed.icon = run_texture
		elif GameManager.player_character.player_speed == 3:
			change_move_speed.icon = walk_texture
		
		# Report it to the rest of the code
		Signals.ui_change_move_speed_button.emit()
		
