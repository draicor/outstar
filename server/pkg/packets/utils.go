package packets

import "server/internal/server/objects"

/*
	packet := &packets.Packet{
		SenderId: 1,
		Payload:  packets.NewChatMessage("Hello, world"),
	}
*/

// The Packet Struct contains a Payload as an interface called isPacket_Payload
type Payload = isPacket_Payload

// Sent by client to communicate with other clients in the area
func NewPublicMessage(nickname string, text string) Payload {
	return &Packet_PublicMessage{
		PublicMessage: &PublicMessage{
			Nickname: nickname,
			Text:     text,
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
		RequestGranted: &RequestGranted{},
	}
}

// Sent by server if request was unsuccessful
func NewRequestDenied(reason string) Payload {
	return &Packet_RequestDenied{
		RequestDenied: &RequestDenied{
			Reason: reason,
		},
	}
}

// Sent by the client once he arrives and broadcasted to everyone
func NewClientEntered(nickname string) Payload {
	return &Packet_ClientEntered{
		ClientEntered: &ClientEntered{
			Nickname: nickname,
		},
	}
}

// Sent by the client once he leaves, broadcasted to everyone
func NewClientLeft(nickname string) Payload {
	return &Packet_ClientLeft{
		ClientLeft: &ClientLeft{
			Nickname: nickname,
		},
	}
}

// Sent by the client after successful login
func NewLoginSuccess(nickname string) Payload {
	return &Packet_LoginSuccess{
		LoginSuccess: &LoginSuccess{
			Nickname: nickname,
		},
	}
}

// Sent by the server to spawn a new character in the client
func NewSpawnCharacter(id uint64, character *objects.Character) Payload {
	return &Packet_SpawnCharacter{
		SpawnCharacter: &SpawnCharacter{
			Id:         id,
			Name:       character.Name,
			X:          character.X,
			Y:          character.Y,
			Z:          character.Z,
			RotationY:  character.RotationY,
			DirectionX: character.DirectionX,
			DirectionZ: character.DirectionZ,
			Speed:      character.Speed,
		},
	}
}
