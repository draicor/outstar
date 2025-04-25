package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"server/internal/server/math"
	"server/internal/server/objects"
	"time"

	"server/pkg/packets"
)

// SERVER TICKS
// Player movement runs at 2Hz (0.5s ticks)
const PlayerMoveTick float64 = 0.5

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

	// Create an update packet to be sent to everyone in this region
	updatePlayerPacket := packets.NewUpdatePlayer(state.client.GetId(), state.player)

	// Spawn our own character in our client first
	state.client.SendPacket(updatePlayerPacket)
	// Tell everyone else to spawn our character too
	state.client.Broadcast(updatePlayerPacket)

	// Loop over all of the clients in this region
	state.client.GetRegion().Clients.ForEach(func(id uint64, client server.Client) {
		// Create an update packet to be sent to our new client
		updatePlayerPacket := packets.NewUpdatePlayer(id, client.GetPlayerCharacter())
		state.client.SendPacket(updatePlayerPacket)
	})

	// Start the player update loop in its own co-routine
	if state.cancelPlayerUpdateLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		state.cancelPlayerUpdateLoop = cancel
		go state.playerUpdateLoop(ctx)
	}
}

// Keeps an accurate representation of the character's position on the server
func (state *Game) updateCharacter() {
	// If we are already at our destination, we are done moving
	if state.player.GetGridPosition() == state.player.GetGridDestination() {
		return
	}

	// Get the grid from this region
	grid := state.client.GetRegion().Grid

	// Calculate the shortest path from our position to our new destination cell
	path := grid.AStar(state.player.GetGridPosition(), state.player.GetGridDestination())

	// If the path is valid
	if len(path) > 1 {
		// We keep track of our steps
		var steps uint64 = 0
		totalSteps := uint64(len(path) - 1) // We subtract one because the first doesn't count

		// We account for our max distance per tick here using Speed
		stepsRemaining := math.MinimumUint64(totalSteps, state.player.Speed)

		// Get the grid from this region
		grid := state.client.GetRegion().Grid

		// Based on our player's speed and the remaining cells to traverse
		// We determine how many cells we can move
		for steps < stepsRemaining {
			// Get the next cell from our path
			nextCell := path[1]

			// If the next cell exists
			if nextCell != nil {
				// If the next cell is both reachable and not occupied
				if grid.IsCellReachable(nextCell) && grid.IsCellAvailable(nextCell) {
					// Move our character into that cell in our region grid
					grid.SetObject(nextCell, state.player)
					// Keep track of our position in our player character
					state.player.SetGridPosition(nextCell)
					// We overwrite our path variable to remove the first cell
					path = path[1:]
					// We mark our step as completed
					steps++

				} else {
					// If the next cell is not valid or occupied
					fmt.Println("Next cell is not valid or occupied")
					break
				}
			} else {
				// If the next cell is invalid
				fmt.Println("Next cell is invalid")
				break
			}
		}

		// If we didn't move
		if steps == 0 {
			fmt.Println("We didn't move for some reason, so abort...")
			// We forget about our destination since its not reachable
			state.player.SetGridDestination(state.player.GetGridPosition())
		}

		// Create a packet and broadcast it to everyone to update the character's position
		updatePlayerPacket := packets.NewUpdatePlayer(state.client.GetId(), state.player)

		// Only if we moved
		if steps > 0 {
			// Broadcast the new player position to everyone else
			state.client.Broadcast(updatePlayerPacket)
		}

		// Send the update to the client that owns this character,
		// so they can ensure they are in sync with the server.
		// We are sending this in a goroutine so we don't block our game loop
		go state.client.SendPacket(updatePlayerPacket)
	}
}

// Runs in a loop updating the player
func (state *Game) playerUpdateLoop(ctx context.Context) {
	ticker := time.NewTicker(time.Duration(PlayerMoveTick*1000) * time.Millisecond)
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
			// The server ignores the client's character name from the packet,
			// it broadcasts the message with the client's nickname from memory
			nickname := state.client.GetPlayerCharacter().Name
			state.HandlePublicMessage(nickname, casted_payload.PublicMessage.Text)

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
		// <- TO FIX
		// Filter per packet type and distance so we can decide if we SHOULD see this
		state.client.SendPacketAs(senderId, payload)
	}
}

// Tell everybody we sent a public message
func (state *Game) HandlePublicMessage(nickname string, text string) {
	state.client.Broadcast(packets.NewPublicMessage(nickname, text))
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
	// time.Sleep(500 * time.Millisecond) // Simulate 500ms delay

	// Get the grid from this region
	grid := state.client.GetRegion().Grid
	// Get the cell the player wants to access
	destination := grid.LocalToMap(payload.X, payload.Z)
	// Only update the player's destination if the cell is valid and unoccupied
	if grid.IsCellReachable(destination) && grid.IsCellAvailable(destination) {
		// We compare our new destination to our previous one
		previousDestination := state.player.GetGridDestination()
		// If the new destination is NOT the same one we already had
		if previousDestination != destination {
			// Overwrite the destination
			state.player.SetGridDestination(destination)
		} // New destination is the same as our previous one, ignore
	} // New destination was invalid, ignore
}

func (state *Game) OnExit() {
	// We don't broadcast the client leaving here because
	// we are doing it from the websocket.go

	// Store this client's data to the database before leaving this state

	// We stop the player update loop if we leave the Game state
	if state.cancelPlayerUpdateLoop != nil {
		state.cancelPlayerUpdateLoop()
	}

	// We are removing the player from the grid in the region code

	// Remove this player from the list of players from the Hub
	state.client.GetHub().SharedObjects.Players.Remove(state.client.GetId())
}
