package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"

	"server/pkg/packets"
)

type Lobby struct {
	client  server.ClientInterfacer
	logger  *log.Logger
	queries *db.Queries
	dbCtx   context.Context
}

func (state *Lobby) GetName() string {
	return "Lobby"
}

func (state *Lobby) SetClient(client server.ClientInterfacer) {
	// We save the client's data into this state
	state.client = client
	state.queries = client.GetDBTX().Queries
	state.dbCtx = client.GetDBTX().Ctx

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Lobby) OnEnter() {
	// FIX THIS
	// We don't broadcast this client's arrival here because
	// we are doing it from the Godot client
}

func (state *Lobby) HandlePacket(senderId uint64, payload packets.Payload) {
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

		// CREATE ROOM REQUEST
		case *packets.Packet_CreateRoomRequest:
			state.HandleCreateRoomRequest()

		// JOIN ROOM REQUEST
		case *packets.Packet_JoinRoomRequest:
			state.HandleJoinRoomRequest(casted_payload)

		// GET ROOMS REQUEST
		case *packets.Packet_GetRoomsRequest:
			state.HandleGetRoomsRequest(casted_payload)

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
func (state *Lobby) HandleClientEntered(nickname string) {
	state.client.Broadcast(packets.NewClientEntered(nickname))
}

// We send this message to everybody
func (state *Lobby) HandleClientLeft(nickname string) {
	state.client.Broadcast(packets.NewClientLeft(nickname))
}

func (state *Lobby) OnExit() {
	// FIX THIS
	// We don't broadcast the client leaving here because
	// we are doing it from the websocket.go
}

// Sent by the client to request creating a new room
func (state *Lobby) HandleCreateRoomRequest() {
	state.client.CreateRoom()
}

// Sent by the client to request joining a room
func (state *Lobby) HandleJoinRoomRequest(payload *packets.Packet_JoinRoomRequest) {
	state.client.JoinRoom(payload.JoinRoomRequest.GetRoomId())
}

// Sent by the client requesting the list of available rooms
func (state *Lobby) HandleGetRoomsRequest(payload *packets.Packet_GetRoomsRequest) {
	// Request the room list from the client [client requests it from the hub]
	rooms := state.client.GetRoomList()
	// If there are no rooms created, inform the client
	if rooms.Len() < 1 {
		state.client.SocketSend(packets.NewRequestDenied("No rooms available"))
	}

	// Create an empty map that will hold RoomInfo packets
	roomsPacket := make([]*packets.RoomInfo, 0, rooms.Len())

	// For each room in the rooms collection fetched from the Hub
	rooms.ForEach(func(id uint64, room server.Room) {
		// Extract the data from the room, create a single packet for each room and add it to the list
		roomsPacket = append(roomsPacket, packets.CreateRoomInfo(id, 3, 99)) // <- FIX THIS
	})

	state.logger.Printf("%s requested the room list", state.client.GetNickname())
	// Send the list of rooms to the client
	state.client.SocketSend(packets.NewRoomList(roomsPacket))
}
