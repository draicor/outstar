extends Node

const packets := preload("res://packets.gd")

func _ready() -> void:
	var new_packet := packets.Packet.new()
	# new_packet.from_bytes([8, 69, 18, 15, 10, 13, 72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33])
	new_packet.set_sender_id(1)
	new_packet.new_chat_message().set_text("Hey there")
	
	print(new_packet)
	print(new_packet.has_chat_message())
	print(new_packet.to_bytes())
	
	if new_packet.has_chat_message():
		pass
	elif new_packet.has_client_id():
		pass
	else:
		pass
