extends Node

const packets := preload("res://packets.gd")

# I disabled unused signal warnings:
# under Project > Project Settings > Debug > GDScript

# Multiplayer Websocket signals
signal connected_to_server
signal connection_closed
signal packet_received(packet: packets.Packet)
signal heartbeat_attempt
signal heartbeat_sent

# Login signals
signal login_success

# Multiplayer packets
signal heartbeat_received

# User Interface signals
signal ui_escape_menu_toggle
signal ui_logout
signal ui_chat_input_toggle
signal ui_zoom_in
signal ui_zoom_out
signal ui_rotate_camera_left
signal ui_rotate_camera_right
signal ui_change_move_speed_button(new_move_speed: int)
signal ui_hide_bottom_right_hud
signal ui_show_bottom_right_hud
signal ui_update_ammo
signal ui_controls_menu_toggle

# Chat signals
signal chat_public_message_sent(text: String)

# Player state signals
signal player_character_spawned
signal player_locomotion_changed(anim_state: String)
signal player_interaction_finished
signal player_update_locomotion_animation(cells_to_move: int)
