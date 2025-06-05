package packets

import "server/internal/server/objects"

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
func NewHandshake(version string) Payload {
	return &Packet_Handshake{
		Handshake: &Handshake{
			Version: version,
		},
	}
}

// Used to keep connection alive
func NewHeartbeat() Payload {
	return &Packet_Heartbeat{
		Heartbeat: &Heartbeat{},
	}
}

// Sent by server with server info to the client
func NewServerMetrics(playersOnline uint64) Payload {
	return &Packet_ServerMetrics{
		ServerMetrics: &ServerMetrics{
			PlayersOnline: playersOnline,
		},
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

// Sent by the client after successful login
func NewLoginSuccess(nickname string) Payload {
	return &Packet_LoginSuccess{
		LoginSuccess: &LoginSuccess{
			Nickname: nickname,
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
func NewClientLeft(id uint64, nickname string) Payload {
	return &Packet_ClientLeft{
		ClientLeft: &ClientLeft{
			Id:       id,
			Nickname: nickname,
		},
	}
}

// Sent by the server as metadata (map name, grid size, static obstacles?, gates?)
func NewRegionData(regionId uint64, gridWidth uint64, gridHeight uint64) Payload {
	return &Packet_RegionData{
		RegionData: &RegionData{
			RegionId:   regionId,
			GridWidth:  gridWidth,
			GridHeight: gridHeight,
		},
	}
}

// Used internaly by the server to generate a path of positions
func NewPosition(x, z uint64) Payload {
	return &Packet_Position{
		Position: &Position{
			X: x,
			Z: z,
		},
	}
}

// Sent by the server to update a player character
func NewUpdatePlayer(id uint64, player *objects.Player) Payload {
	position := player.GetGridPosition()

	return &Packet_UpdatePlayer{
		UpdatePlayer: &UpdatePlayer{
			Id:   id,
			Name: player.Name,
			Position: &Position{
				X: position.X,
				Z: position.Z,
			},
			RotationY: player.RotationY,
			Gender:    player.GetGender(),
			Speed:     player.GetSpeed(),
		},
	}
}

// Sent by both client and server to update a player character's movement speed
func NewUpdateSpeed(newSpeed uint64) Payload {
	return &Packet_UpdateSpeed{
		UpdateSpeed: &UpdateSpeed{
			Speed: newSpeed,
		},
	}
}

// Sent by both client and server to toggle the chat bubble of a character
func NewChatBubble(isActive bool) Payload {
	return &Packet_ChatBubble{
		ChatBubble: &ChatBubble{
			IsActive: isActive,
		},
	}
}
