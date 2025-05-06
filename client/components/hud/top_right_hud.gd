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
	if GameManager.player_character.current_animation != GameManager.player_character.ASM.IDLE:
		return
	
	# Left click increases speed
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Left click detected, increase speed
		if GameManager.player_character.player_speed == 3:
			# Already at max speed, ignore this
			return
		# If I was jogging, start running
		elif GameManager.player_character.player_speed == 2:
			texture_rect.texture = run_texture
			Signals.ui_change_move_speed_button.emit(3) # RUN
		# If I was walking, start jogging
		elif GameManager.player_character.player_speed == 1:
			texture_rect.texture = jog_texture
			Signals.ui_change_move_speed_button.emit(2) # JOG
	
	# Right click decreases speed
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Right click detected, decrease speed
		if GameManager.player_character.player_speed == 1:
			# Already at min speed, ignore this
			return
		# If I was jogging, start walking
		elif GameManager.player_character.player_speed == 2:
			texture_rect.texture = walk_texture
			Signals.ui_change_move_speed_button.emit(1) # WALK
		# If I was running, start jogging
		elif GameManager.player_character.player_speed == 3:
			texture_rect.texture = jog_texture
			Signals.ui_change_move_speed_button.emit(2) # JOG
