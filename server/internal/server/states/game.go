package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"

	"server/pkg/packets"
)

type Game struct {
	client  server.ClientInterfacer
	logger  *log.Logger
	queries *db.Queries
	dbCtx   context.Context
}

func (state *Game) GetName() string {
	return "Game"
}

func (state *Game) SetClient(client server.ClientInterfacer) {
	// We save the client's data into this state
	state.client = client
	state.queries = client.GetDBTX().Queries
	state.dbCtx = client.GetDBTX().Ctx

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Game) OnEnter() {
	// TO FIX
	// We need to get this client's region and location from the database
	// then move him to that region and spawn him
	state.client.GetHub().JoinRegion(state.client.GetId(), 1)
}

func (state *Game) HandlePacket(senderId uint64, payload packets.Payload) {
	// If this packet was sent by our client
	if senderId == state.client.GetId() {
		// Switch based on the type of packet
		// We also save the casted packet in case we need to access specific fields
		switch casted_payload := payload.(type) {

		// PUBLIC MESSAGE
		case *packets.Packet_PublicMessage:
			// The server ignores the client's character name from the packet, takes the data and
			// constructs a new public message with the client's nickname from memory
			nickname := state.client.GetCharacter().GetName()
			text := casted_payload.PublicMessage.Text
			state.client.Broadcast(packets.NewPublicMessage(nickname, text))

		// HEARTBEAT
		case *packets.Packet_Heartbeat:
			state.client.SendPacket(packets.NewHeartbeat())

		// CLIENT ENTERED
		case *packets.Packet_ClientEntered:
			state.HandleClientEntered(state.client.GetCharacter().GetName())

		// CLIENT LEFT
		case *packets.Packet_ClientLeft:
			state.HandleClientLeft(state.client.GetCharacter().GetName())

		case nil:
			// Ignore packet if not a valid payload type
		default:
			// Ignore packet if no payload was sent
		}

	} else {
		// If another client passed us this packet, forward it to our client
		// TO FIX
		// Filter per packet type and distance so we can decide if we SHOULD see this
		state.client.SendPacketAs(senderId, payload)
	}
}

// We send this message to everybody
func (state *Game) HandleClientEntered(nickname string) {
	state.client.Broadcast(packets.NewClientEntered(nickname))
}

// We send this message to everybody
func (state *Game) HandleClientLeft(nickname string) {
	state.client.Broadcast(packets.NewClientLeft(nickname))
}

func (state *Game) OnExit() {
	// TO FIX
	// We don't broadcast the client leaving here because
	// we are doing it from the websocket.go

	// Store this client's data to the database before leaving this state
}
