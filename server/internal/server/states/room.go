package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"

	"server/pkg/packets"
)

type Room struct {
	client  server.ClientInterfacer
	logger  *log.Logger
	queries *db.Queries
	dbCtx   context.Context
}

func (state *Room) GetName() string {
	return "Room"
}

func (state *Room) SetClient(client server.ClientInterfacer) {
	// We save the client's data into this state
	state.client = client
	state.queries = client.GetDBTX().Queries
	state.dbCtx = client.GetDBTX().Ctx

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Room) OnEnter() {
	// A newly connected client will receive its own ID
	state.client.SocketSend(packets.NewHandshake())

	// We don't broadcast this client's arrival here because
	// we are doing it from the Godot client
}

func (state *Room) HandlePacket(senderId uint64, payload packets.Payload) {
	// If this packet was sent by our client
	if senderId == state.client.GetId() {
		// Switch based on the type of packet
		// We also save the casted packet in case we need to access specific fields
		switch casted_payload := payload.(type) {

		// PUBLIC MESSAGE
		case *packets.Packet_PublicMessage:
			// The server ignores the client's nickname from the packet, takes the data and
			// constructs a new public message with the client's nickname from memory
			nickname := state.client.GetNickname()
			text := casted_payload.PublicMessage.Text
			state.client.Broadcast(packets.NewPublicMessage(nickname, text))

		// HEARTBEAT
		case *packets.Packet_Heartbeat:
			state.client.SocketSend(packets.NewHeartbeat())

		// CLIENT ENTERED
		case *packets.Packet_ClientEntered:
			state.HandleClientEntered(state.client.GetNickname())

		// CLIENT LEFT
		case *packets.Packet_ClientLeft:
			state.HandleClientLeft(state.client.GetNickname())

		// LEAVE ROOM REQUEST
		case *packets.Packet_LeaveRoomRequest:
			state.HandleLeaveRoomRequest()

		// TAKE SLOT REQUEST
		case *packets.Packet_TakeSlotRequest:
			state.HandleTakeSlotRequest(casted_payload.TakeSlotRequest.GetSlotId())

		// LEAVE SLOT REQUEST
		case *packets.Packet_LeaveSlotRequest:
			state.HandleLeaveSlotRequest()

		case nil:
			// Ignore packet if not a valid payload type
		default:
			// Ignore packet if no payload was sent
		}

	} else {
		// If another client passed us this packet, forward it to our client
		state.client.SocketSendAs(payload, senderId)
	}
}

// We send this message to everybody
func (state *Room) HandleClientEntered(nickname string) {
	state.client.Broadcast(packets.NewClientEntered(nickname))
}

// We send this message to everybody
func (state *Room) HandleClientLeft(nickname string) {
	state.client.Broadcast(packets.NewClientLeft(nickname))
}

func (state *Room) OnExit() {
	// pass
}

// Sent by the client to request leaving a room
func (state *Room) HandleLeaveRoomRequest() {
	state.client.LeaveRoom()
}

// Sent by the client to request occupying a slot inside the room
func (state *Room) HandleTakeSlotRequest(slotId uint64) {
	// We get the room this client is in
	room := state.client.GetRoom()
	// We attempt to take the slot
	success := room.TakeSlot(slotId, state.client)
	if success {
		state.client.SocketSend(packets.NewRequestGranted())
	} else {
		state.client.SocketSend(packets.NewRequestDenied("Slot not available"))
	}
}

// Sent by the client to request leaving a slot inside the room
func (state *Room) HandleLeaveSlotRequest() {
	// We get the room this client is in
	room := state.client.GetRoom()
	// We attempt to leave the slot
	success := room.LeaveSlot(state.client)
	if success {
		state.client.SocketSend(packets.NewRequestGranted())
	} else {
		state.client.SocketSend(packets.NewRequestDenied("You are not occupying any slot"))
	}
}
