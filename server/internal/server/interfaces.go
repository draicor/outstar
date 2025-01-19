package server

import (
	"server/internal/server/objects"
	"server/pkg/packets"
)

// A structure for the connected client to interface with the server
type ClientInterfacer interface {
	// Returns the Hub this client is connected to
	GetHub() *Hub

	// Returns the client's ID
	GetId() uint64

	// Returns true if this client has already been initialized by the server (has id)
	HasId() bool

	// Handles the client's message
	ProcessMessage(senderId uint64, message packets.Payload)

	// Sets the client's ID
	Initialize(id uint64)

	// Puts data from the client into the write pump
	SocketSend(message packets.Payload)

	// Puts data from another client in the write pump
	SocketSendAs(message packets.Payload, senderId uint64)

	// Forward message to another client for processing
	PassToPeer(message packets.Payload, peerId uint64)

	// Forward message to all other clients for processing
	Broadcast(message packets.Payload)

	// Pump data from the connected socket directly to the client
	ReadPump()

	// Pump data from the client directly to the connected socket
	WritePump()

	// Close the client's connection and cleanup
	Close(reason string)

	// Updates the state of this client
	SetState(newState ClientStateHandler)

	// Get reference to the database transaction context for this client
	GetDBTX() *DBTX

	// Updates the nickname of this client on login
	SetNickname(nickname string)

	// Returns this client's nickname
	GetNickname() string

	// Returns this client's current room
	GetRoom() *Room

	// TO DO -> MOVE ALL OF THIS TO A LOBBY STRUCT
	// Attempts to create a room [called from lobby state]
	CreateRoom(maxPlayers uint64)

	// Attempts to join a room by id [called from lobby state]
	JoinRoom(roomId uint64)

	// Leaves the current room and goes back to the Hub [called from room state]
	LeaveRoom()

	// Request the list of rooms
	GetRoomList() *objects.SharedCollection[*Room]
}

// A structure for a state machine to process the client's messages
type ClientStateHandler interface {
	GetName() string

	// Inject the client into the state handler, so we can access the client's data
	SetClient(client ClientInterfacer)

	// Triggers once a client switches to this state
	OnEnter()

	// Handles the packets received in this state
	HandlePacket(senderId uint64, payload packets.Payload)

	// Triggers once a client leaves this state
	OnExit()
}
