extends Control

@export var walk_texture: CompressedTexture2D = preload("res://assets/icons/icon_movement_speed_walk.png")
@export var jog_texture: CompressedTexture2D = preload("res://assets/icons/icon_movement_speed_jog.png")
@export var run_texture: CompressedTexture2D = preload("res://assets/icons/icon_movement_speed_run.png")


@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	texture_rect.texture = run_texture


# Request the server to change the movement speed
func _on_change_move_speed_button_down() -> void:
	# Only send the packet to update our speed if we are IDLE
	if GameManager.player_character.current_animation == GameManager.player_character.ASM.IDLE:
		if GameManager.player_character.player_speed == 1:
			texture_rect.texture = jog_texture
		elif GameManager.player_character.player_speed == 2:
			texture_rect.texture = run_texture
		elif GameManager.player_character.player_speed == 3:
			texture_rect.texture = walk_texture
		
		# Report it to the rest of the code
		Signals.ui_change_move_speed_button.emit()
