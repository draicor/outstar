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

	// Sets the client's ID and loads the character from the database after login
	Initialize(id uint64)

	// Handles the client's packet
	ProcessPacket(senderId uint64, packet packets.Payload)

	// Puts data from the client into the write pump
	SendPacket(packet packets.Payload)

	// Puts data from another client in the write pump
	SendPacketAs(peerId uint64, packet packets.Payload)

	// Forward packet to another client for processing
	RelayPacket(peerId uint64, packet packets.Payload)

	// Forward packet to all other clients for processing
	Broadcast(packet packets.Payload)

	// Start reading data from the game client
	StartReadPump()

	// Start writing data to the game client
	StartWritePump()

	// Updates the state of this client
	SetState(newState ClientStateHandler)

	// REMOVE THIS DEPENDENCY
	// Get reference to the database transaction context for this client
	GetDBTX() *DBTX

	// Character get/set
	GetCharacter() *objects.Character
	SetCharacter(*objects.Character)

	// Region get/set
	GetRegion() *Region
	SetRegion(*Region)

	// Close the client's connection and cleanup
	Close(reason string)
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
