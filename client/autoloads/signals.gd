extends Node

const packets := preload("res://packets.gd")

# Disabled unused signal warnings under Project > Project Settings > Debug > GDScript

# UDP Multiplayer signals
#signal connection_failed
#signal peer_connected(peer_id) # Everyone gets this signal
#signal peer_disconnected(peer_id) # Everyone gets this signal

# Multiplayer Websocket signals
signal connected_to_server
signal connection_closed
signal packet_received(packet: packets.Packet)
signal heartbeat_attempt
signal heartbeat_sent

# Multiplayer packets
signal heartbeat_received

# Browser signals
signal browser_join_room(room_id: int)

# Input signals
signal ui_escape_menu_toggle
signal ui_chat_input_toggle
signal ui_leave_room
#signal ui_disconnect
