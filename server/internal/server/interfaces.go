package server

import (
	"server/internal/server/objects"
	"server/pkg/packets"
)

// Interface between the connected client and the server
type Client interface {
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

	// Gets the processing packets channel
	GetProcessingChannel() chan *packets.Packet

	// Start reading data from the game client
	StartReadPump()

	// Start writing data to the game client
	StartWritePump()

	// Updates the state of this client
	SetState(newState ClientState)

	// PlayerCharacter get/set
	GetPlayerCharacter() *objects.Player
	SetPlayerCharacter(*objects.Player)

	// AccountUsername get/set
	GetAccountUsername() string
	SetAccountUsername(username string)

	// Region get/set
	GetRegion() *Region
	SetRegion(*Region)

	// Close the client's connection and cleanup
	Close(reason string)
}

// State machine to process the client's messages
type ClientState interface {
	GetName() string

	// Inject the client into the state, so we can access the client's data
	SetClient(client Client)

	// Triggers once a client switches to this state
	OnEnter()

	// Handles the packets received in this state
	HandlePacket(senderId uint64, payload packets.Payload)

	// Triggers once a client leaves this state
	OnExit()
}
