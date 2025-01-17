package packets

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

// Sent by the server to ask the client to switch to the room state
func NewJoinRoomSuccess() Payload {
	return &Packet_JoinRoomSuccess{
		JoinRoomSuccess: &JoinRoomSuccess{},
	}
}

// Sent by the server to ask the client to switch to the lobby state
func NewLeaveRoomSuccess() Payload {
	return &Packet_LeaveRoomSuccess{
		LeaveRoomSuccess: &LeaveRoomSuccess{},
	}
}

// Auxiliary function to get the data we need in pieces and assemble the packet's contents
func CreateRoomInfo(roomId uint64, master string, mapName string, playersOnline uint64, maxPlayers uint64) *RoomInfo {
	return &RoomInfo{
		RoomId:        roomId,
		Master:        master,
		MapName:       mapName,
		PlayersOnline: playersOnline,
		MaxPlayers:    maxPlayers,
	}
}

// Data from a room used in the RoomList packet
func NewRoomInfo(roomId uint64, master string, mapName string, playersOnline uint64, maxPlayers uint64) Payload {
	return &Packet_RoomInfo{
		RoomInfo: CreateRoomInfo(roomId, master, mapName, playersOnline, maxPlayers),
	}
}

// List of packets with every available room sent by the server
func NewRoomList(rooms []*RoomInfo) Payload {
	return &Packet_RoomList{
		&RoomList{
			RoomList: rooms,
		},
	}
}
