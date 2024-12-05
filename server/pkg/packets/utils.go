package packets

// The Packet Struct contains a Payload as an interface called isPacket_Payload
type Payload = isPacket_Payload

func NewChatMessage(text string) Payload {
	return &Packet_ChatMessage{
		ChatMessage: &Chat{
			Text: text,
		},
	}
}

func NewClientId(id uint64) Payload {
	return &Packet_ClientId{
		ClientId: &ClientId{
			Id: id,
		},
	}
}
