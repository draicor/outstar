package packets

import (
	"server/internal/server/objects"
)

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

// Convert weapon slots to protobuf format
func convertWeaponsToProto(weapons []*objects.WeaponSlot) []*WeaponSlot {
	var pbSlots []*WeaponSlot
	for slotIndex, weapon := range weapons {
		if weapon != nil {
			pbSlots = append(pbSlots, &WeaponSlot{
				SlotIndex:   uint64(slotIndex),
				WeaponName:  weapon.WeaponName,
				WeaponType:  weapon.WeaponType,
				DisplayName: weapon.DisplayName,
				Ammo:        weapon.Ammo,
				FireMode:    weapon.FireMode,
			})
		}
	}
	return pbSlots
}

// Sent by the server to spawn a character
func NewSpawnCharacter(id uint64, player *objects.Player) Payload {
	position := player.GetGridPosition()

	return &Packet_SpawnCharacter{
		SpawnCharacter: &SpawnCharacter{
			Id:   id,
			Name: player.Name,
			Position: &Position{
				X: position.X,
				Z: position.Z,
			},
			RotationY:     player.GetRotation(),
			Gender:        player.GetGender(),
			Speed:         player.GetSpeed(),
			CurrentWeapon: player.GetCurrentWeapon(),
			Weapons:       convertWeaponsToProto(*player.GetWeapons()),
		},
	}
}

// Sent by the server to update a character's grid position
func NewMoveCharacter(id uint64, player *objects.Player) Payload {
	position := player.GetGridPosition()

	return &Packet_MoveCharacter{
		MoveCharacter: &MoveCharacter{
			Id: id,
			Position: &Position{
				X: position.X,
				Z: position.Z,
			},
		},
	}
}

// Sent by both client and server to update a character's movement speed
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

// Sent by both client and server to broadcast weapon state
func NewSwitchWeapon(slot uint64) Payload {
	return &Packet_SwitchWeapon{
		SwitchWeapon: &SwitchWeapon{
			Slot: slot,
		},
	}
}
