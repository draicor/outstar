package packets

/*
	packet := &packets.Packet{
		SenderId: 1,
		Payload:  packets.NewChatMessage("Hello, world"),
	}
*/

// The Packet Struct contains a Payload as an interface called isPacket_Payload
type Payload = isPacket_Payload

// Sent by client to communicate with other clients
func NewChatMessage(text string) Payload {
	return &Packet_ChatMessage{
		ChatMessage: &Chat{
			Text: text,
		},
	}
}

// Sent by server after client connects
func NewHandshake() Payload {
	return &Packet_Handshake{
		Handshake: &Handshake{},
	}
}

// Used to keep connection alive
func NewHeartbeat() Payload {
	return &Packet_Heartbeat{
		Heartbeat: &Heartbeat{},
	}
}

// Sent by server if request was successful
func NewRequestGranted() Payload {
	return &Packet_RequestGranted{
		RequestGranted: &Granted{},
	}
}

// Sent by server if request was unsuccessful
func NewRequestDenied(reason string) Payload {
	return &Packet_RequestDenied{
		RequestDenied: &Denied{
			Reason: reason,
		},
	}
}
