extends Control

@export var walk_texture: CompressedTexture2D = preload("res://assets/icons/icon_movement_speed_walk.png")
@export var jog_texture: CompressedTexture2D = preload("res://assets/icons/icon_movement_speed_jog.png")
@export var run_texture: CompressedTexture2D = preload("res://assets/icons/icon_movement_speed_run.png")


@onready var texture_rect: TextureRect = $TextureRect

var button_enabled: bool = true # Enabled by default


func _ready() -> void:
	Signals.player_character_spawned.connect(_handle_signal_player_character_spawned)
	Signals.player_locomotion_changed.connect(_handle_signal_player_locomotion_changed)
	hide()


func _handle_signal_player_character_spawned() -> void:
	if not GameManager.player_character:
		return
	
	# Get our player_speed from the GameManager after spawm
	if GameManager.player_character.player_speed == 1:
		texture_rect.texture = walk_texture
	elif GameManager.player_character.player_speed == 2:
		texture_rect.texture = jog_texture
	elif GameManager.player_character.player_speed == 3:
		texture_rect.texture = run_texture
	
	show()

# Toggles this button based on the current locomotion state of the player
func _handle_signal_player_locomotion_changed(anim_state: String) -> void:
	# If we are in our idle state, enable the button
	if anim_state == "idle":
		button_enabled = true
		texture_rect.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	else: # Disable the button
		button_enabled = false
		texture_rect.self_modulate = Color(1.0, 1.0, 1.0, 0.33)


# Request the server to change the movement speed
func _on_change_move_speed_button_down() -> void:
	# Stop click event from propagating through this button
	get_viewport().set_input_as_handled()
	
	if not button_enabled:
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
