extends Node

const packets := preload("res://packets.gd")

# Disabled Unused Signal warnings under Project > Project Settings > Debug > GDScript

# Multiplayer signals
# signal connected_to_server
# signal connection_failed
# signal peer_connected(peer_id) # Everyone gets this signal
# signal peer_disconnected(peer_id) # Everyone gets this signal
# signal server_disconnected

# Websocket signals
signal connected_to_server()
signal connection_closed()
signal packet_received(packet: packets.Packet)

# Input signals
signal ui_escape_menu_toggle
signal ui_chat_input_toggle
#signal ui_disconnect
