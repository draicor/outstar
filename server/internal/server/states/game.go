package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"server/internal/server/objects"
	"time"

	"server/pkg/packets"
)

const PlayerTick float64 = 0.6

type Game struct {
	client                 server.Client
	player                 *objects.Player
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
	state.player = client.GetPlayerCharacter()
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

	//	Start the player update loop in its own co-routine
	if state.cancelPlayerUpdateLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		state.cancelPlayerUpdateLoop = cancel
		go state.playerUpdateLoop(ctx)
	}

	// Create an update packet to be sent to everyone in this region
	updatePlayerPacket := packets.NewUpdatePlayer(state.client.GetId(), state.player)

	// Spawn our own character in our client first
	state.client.SendPacket(updatePlayerPacket)
	// Tell everyone else to spawn our character too
	state.client.Broadcast(updatePlayerPacket)
}

// Attempts to keep an accurate representation of the character's position on the server
func (state *Game) updateCharacter() {
	// Get the grid from this region
	grid := state.client.GetRegion().Grid
	// Get the player's current grid position
	gridPosition := state.player.GetGridPosition()
	// Get the player's target grid position
	targetPosition := grid.GetValidatedCell(state.player.DestinationX, state.player.DestinationZ)

	// If the target cell is not valid, abort
	if targetPosition == nil {
		return
	}
	// If the player is already at the target position, abort
	if gridPosition == targetPosition {
		return
	}

	// Overwrite this player character's grid position in the server
	grid.SetObject(targetPosition, state.player)

	// Create a packet and broadcast it to everyone to update the character's position
	updatePlayerPacket := packets.NewUpdatePlayer(state.client.GetId(), state.player)
	state.client.Broadcast(updatePlayerPacket)
	// Send the update to the client that owns this character, so they can ensure
	// they are in sync with the server (this can cause rubber banding)
	// We are sending this in a goroutine so we don't block our game loop
	go state.client.SendPacket(updatePlayerPacket)
}

// Runs in a loop updating the player
func (state *Game) playerUpdateLoop(ctx context.Context) {
	ticker := time.NewTicker(time.Duration(PlayerTick*1000) * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			state.updateCharacter()
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
			nickname := state.client.GetPlayerCharacter().Name
			text := casted_payload.PublicMessage.Text
			state.client.Broadcast(packets.NewPublicMessage(nickname, text))

		// HEARTBEAT
		case *packets.Packet_Heartbeat:
			state.client.SendPacket(packets.NewHeartbeat())

		// CLIENT ENTERED
		case *packets.Packet_ClientEntered:
			state.HandleClientEntered(state.client.GetPlayerCharacter().Name)

		// CLIENT LEFT
		case *packets.Packet_ClientLeft:
			state.HandleClientLeft(state.client.GetId(), state.client.GetPlayerCharacter().Name)

		// PLAYER DESTINATION
		case *packets.Packet_PlayerDestination:
			state.HandlePlayerDestination(casted_payload.PlayerDestination)

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
func (state *Game) HandleClientLeft(id uint64, nickname string) {
	state.client.Broadcast(packets.NewClientLeft(id, nickname))
}

// Sent from the client to the server to request setting a new destination for their player character
func (state *Game) HandlePlayerDestination(payload *packets.PlayerDestination) {
	state.player.DestinationX = payload.X // Left/Right
	state.player.DestinationZ = payload.Z // Forward/backward
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
