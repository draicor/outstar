package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"

	"server/pkg/packets"
)

type Connected struct {
	client  server.ClientInterfacer
	logger  *log.Logger
	queries *db.Queries
	dbCtx   context.Context
}

func (state *Connected) GetName() string {
	return "Connected"
}

func (state *Connected) SetClient(client server.ClientInterfacer) {
	// We save the client's data into this state
	state.client = client
	state.queries = client.GetDBTX().Queries
	state.dbCtx = client.GetDBTX().Ctx

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Connected) OnEnter() {
	// A newly connected client will receive its own ID
	state.client.SocketSend(packets.NewHandshake())

	// After sending the Handshake packet to the client, switch to the Authentication state
	state.client.SetState(&Authentication{})
}

func (state *Connected) HandlePacket(senderId uint64, payload packets.Payload) {
	// On this state, we don't need to listen for any packets yet
	// We'll implement a version check packet before sending the Handshake packet in the future
}

func (state *Connected) OnExit() {
	// pass
}
