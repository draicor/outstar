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

// Sent by the client after successful login
func NewLoginSuccess(nickname string) Payload {
	return &Packet_LoginSuccess{
		LoginSuccess: &LoginSuccess{
			Nickname: nickname,
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
	// Create an empty array of Positions
	var path []*Position

	// If the player has no path set
	if player.Path == nil || len(player.Path) < 1 {
		// Just take the current grid position
		position := player.GetGridPosition
		path = append(path, &Position{
			X: position().X,
			Z: position().Z,
		})
	}

	// If the player has a path
	if len(player.Path) > 0 {
		// We iterate over the player's path
		for _, cell := range player.Path {
			// And we add the positions of every cell in it
			path = append(path, &Position{
				X: cell.X,
				Z: cell.Z,
			})
		}
	}

	// Then we just return the completed packet
	return &Packet_UpdatePlayer{
		UpdatePlayer: &UpdatePlayer{
			Id:        id,
			Name:      player.Name,
			Path:      path,
			RotationY: player.RotationY,
		},
	}
}
