package packets

/*
	packet := &packets.Packet{
		SenderId: 1,
		Payload:  packets.NewChatMessage("Hello, world"),
	}
*/

// The Packet Struct contains a Payload as an interface called isPacket_Payload
type Payload = isPacket_Payload

func NewChatMessage(text string) Payload {
	return &Packet_ChatMessage{
		ChatMessage: &Chat{
			Text: text,
		},
	}
}

func NewHandshake() Payload {
	return &Packet_Handshake{
		Handshake: &Handshake{},
	}
}

func NewHeartbeat() Payload {
	return &Packet_Heartbeat{
		Heartbeat: &Heartbeat{},
	}
}
