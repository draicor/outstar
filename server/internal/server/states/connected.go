package states

import (
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/info"

	"server/pkg/packets"
)

type Connected struct {
	client server.Client
	logger *log.Logger
}

func (state *Connected) GetName() string {
	return "Connected"
}

func (state *Connected) SetClient(client server.Client) {
	// We save the client's data into this state
	state.client = client

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Connected) OnEnter() {
	// A newly connected client will receive its own ID and the server's version
	state.client.SendPacket(packets.NewHandshake(info.Version))
}

func (state *Connected) HandlePacket(senderId uint64, payload packets.Payload) {
	// We listen for the handshake packet from the client

	// If this packet was sent by our client
	if senderId == state.client.GetId() {
		// Switch based on the type of packet
		// We also save the casted packet in case we need to access specific fields
		switch casted_payload := payload.(type) {

		// HANDSHAKE
		case *packets.Packet_Handshake:
			state.HandleHandshake(casted_payload.Handshake)

		case nil:
			// Ignore packet if not a valid payload type
		default:
			// Ignore packet if no payload was sent
		}
	}
}

func (state *Connected) HandleHandshake(payload *packets.Handshake) {
	// Compare the client's version to the server's version as a precaution
	if payload.Version == info.Version {
		// Switch this client to the Authentication state
		state.client.SetState(&Authentication{})
	}
}

func (state *Connected) OnExit() {
	// pass
}
