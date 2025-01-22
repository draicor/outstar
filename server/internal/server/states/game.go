package states

import (
	"context"
	"fmt"
	"log"
	"math"
	"server/internal/server"
	"server/internal/server/db"
	"server/internal/server/objects"
	"time"

	"server/pkg/packets"
)

type Game struct {
	client                 server.Client
	player                 *objects.Character
	cancelPlayerUpdateLoop context.CancelFunc
	logger                 *log.Logger
	queries                *db.Queries
	dbCtx                  context.Context
}

func (state *Game) GetName() string {
	return "Game"
}

// SetClient gets called BEFORE OnEnter() from WebSocketClient
func (state *Game) SetClient(client server.Client) {
	// We save the client's data into this state
	state.client = client
	// We save the client's character data into this state too
	state.player = client.GetCharacter()
	state.queries = client.GetDBTX().Queries
	state.dbCtx = client.GetDBTX().Ctx

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Game) OnEnter() {
	// Add this client's character to the player map of the hub with the same ID as its client ID
	go state.client.GetHub().SharedObjects.Players.Add(state.player, state.client.GetId())

	state.logger.Printf("%s added to region %d", state.player.Name, state.player.RegionId)

	// Move the client to the region his character is at
	state.client.GetHub().JoinRegion(state.client.GetId(), state.player.RegionId)

	// Tell the client to spawn our character
	state.client.SendPacket(packets.NewSpawnCharacter(state.client.GetId(), state.player))
}

// Attempts to keep an accurate representation of the character's position on the server
func (state *Game) synchronizeCharacter(delta float64) {
	// Calculates the new position of the character based on the character’s current direction and speed
	newX := state.player.X + state.player.Speed*math.Cos(state.player.DirectionX)*delta
	newZ := state.player.Z + state.player.Speed*math.Sin(state.player.DirectionZ)*delta

	// Overwrite our player character's position
	state.player.X = newX
	state.player.Z = newZ

	// Create a packet and broadcast it to everyone to update the character's position
	updatePacket := packets.NewSpawnCharacter(state.client.GetId(), state.player)
	state.client.Broadcast(updatePacket)
	// Send the update to the client that owns this character, so they can ensure
	// they are in sync with the server (this can cause rubber banding)
	// We are sending this in a goroutine so we don't block our game loop
	go state.client.SendPacket(updatePacket)
}

// Runs in a loop updating the player's position every 100ms,
func (state *Game) playerUpdateLoop(ctx context.Context) {
	const delta float64 = 0.1
	ticker := time.NewTicker(time.Duration(delta*1000) * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			state.synchronizeCharacter(delta)
		case <-ctx.Done():
			return
		}
	}
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
			nickname := state.client.GetCharacter().Name
			text := casted_payload.PublicMessage.Text
			state.client.Broadcast(packets.NewPublicMessage(nickname, text))

		// HEARTBEAT
		case *packets.Packet_Heartbeat:
			state.client.SendPacket(packets.NewHeartbeat())

		// CLIENT ENTERED
		case *packets.Packet_ClientEntered:
			state.HandleClientEntered(state.client.GetCharacter().Name)

		// CLIENT LEFT
		case *packets.Packet_ClientLeft:
			state.HandleClientLeft(state.client.GetCharacter().Name)

		// CHARACTER DIRECTION
		case *packets.Packet_CharacterDirection:
			state.HandleCharacterDirection(casted_payload.CharacterDirection)

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
	// Tell everybody we connected!
	state.client.Broadcast(packets.NewClientEntered(nickname))
}

// We send this message to everybody
func (state *Game) HandleClientLeft(nickname string) {
	state.client.Broadcast(packets.NewClientLeft(nickname))
}

func (state *Game) HandleCharacterDirection(payload *packets.CharacterDirection) {
	state.player.DirectionX = payload.DirectionX
	state.player.DirectionZ = payload.DirectionZ

	// If this is the first time we are receiving a character direction packet
	// from our client, we start the player update loop
	if state.cancelPlayerUpdateLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		state.cancelPlayerUpdateLoop = cancel
		go state.playerUpdateLoop(ctx)
	}

}

func (state *Game) OnExit() {
	// TO FIX
	// We don't broadcast the client leaving here because
	// we are doing it from the websocket.go

	// Store this client's data to the database before leaving this state

	// We stop the player update loop if we leave the Game state
	if state.cancelPlayerUpdateLoop != nil {
		state.cancelPlayerUpdateLoop()
	}

	// Remove this player from the list of players from the Hub
	state.client.GetHub().SharedObjects.Players.Remove(state.client.GetId())
}
