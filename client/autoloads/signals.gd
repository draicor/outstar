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

# Multiplayer packets
signal heartbeat_received

# Input signals
signal ui_escape_menu_toggle
signal ui_chat_input_toggle
signal ui_change_move_speed_button
#signal ui_disconnect
