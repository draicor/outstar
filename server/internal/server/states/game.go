package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"server/internal/server/math"
	"server/internal/server/objects"
	"server/internal/server/pathfinding"
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

	// Make our character's destination target be our spawn cell so he doesn't move at spawn
	// We use grid destination on the update loop, so if its not set it will crash
	state.player.SetGridDestination(state.player.GetGridPosition())

	// Create a spawn path that only has one element, our spawn position
	var spawnPath []*pathfinding.Cell
	spawnPath = append(spawnPath, state.player.GetGridPosition())
	// Overwrite our path to hold our grid position
	state.player.SetGridPath(spawnPath)

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

	//	Start the player update loop in its own co-routine
	if state.cancelPlayerUpdateLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		state.cancelPlayerUpdateLoop = cancel
		go state.playerUpdateLoop(ctx)
	}
}

// Attempts to keep an accurate representation of the character's position on the server
func (state *Game) updateCharacter() {
	// Get the player's current grid position and destination
	gridPosition := state.player.GetGridPosition()
	targetPosition := state.player.GetGridDestination()

	// If the player is already at the target position
	// This probably never executes, because we have this check in the code that calculates the path
	if gridPosition == targetPosition {
		// Make our grid path null and abort
		state.player.SetGridPath(nil)
		return
	}

	// Get the path for this player
	path := state.player.GetGridPath()
	// If no valid path is found or our path is not long enough, abort
	if path == nil || len(path) < 1 {
		return
	}

	// We keep track of the total steps to take
	totalSteps := uint64(len(path) - 1) // We subtract one because the first doesn't count

	stepsRemaining := math.MinimumUint64(totalSteps, state.player.Speed)
	// We keep track of the path we have traversed so we can broadcast it to the client
	var traversedPath []*pathfinding.Cell
	// We add the first cell to our traversed path
	traversedPath = append(traversedPath, path[0])

	// We keep track of how many steps we have moved in this tick
	var steps uint64 = 0

	// Based on our player's speed and the remaining cells to traverse
	// We determine how many cells we can move
	for steps < stepsRemaining {
		// Get the next cell from our path
		nextCell := path[1]

		// Get the grid from this region
		grid := state.client.GetRegion().Grid

		// If the next cell exists
		if nextCell != nil {
			// If the next cell is valid and available
			if grid.IsValidCell(nextCell) {
				// Move our character into that cell
				grid.SetObject(nextCell, state.player)

				// We add our current cell to the path we have traversed
				traversedPath = append(traversedPath, nextCell)

				// We overwrite our path variable to remove the first cell
				path = path[1:]
				// We mark our step as completed
				steps++

			} else {
				// If the next cell is occupied, stop moving this tick
				break
			}
		} else {
			// If the next cell is invalid, stop moving this tick
			break
		}
	}

	// If we moved at all
	if steps > 0 {
		// We update our player's path so we can send the packet with the path we traversed only!
		state.player.SetGridPath(traversedPath)

		// If we didn't move
	} else {
		// Forget about the path we had
		state.player.SetGridPath(nil)
		// Overwrite our destination with our current position
		state.player.SetGridDestination(state.player.GetGridPosition())
		// Don't send any packets
		return
	}

	// Create a packet and broadcast it to everyone to update the character's position
	updatePlayerPacket := packets.NewUpdatePlayer(state.client.GetId(), state.player)

	// AFTER we create our packet and send it
	// We overwrite the path again with the cells that are left
	state.player.SetGridPath(path)

	// Broadcast the new player position to everyone else
	state.client.Broadcast(updatePlayerPacket)

	// Send the update to the client that owns this character, so they can ensure
	// they are in sync with the server (this can cause rubber banding)
	// We are sending this in a goroutine so we don't block our game loop
	go state.client.SendPacket(updatePlayerPacket)
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
	// CAUTION, for testing only!
	// Simulate 500ms delay
	time.Sleep(2000 * time.Millisecond)

	// Get the grid from this region
	grid := state.client.GetRegion().Grid
	// Get the cell the player wants to access
	destination := grid.LocalToMap(payload.X, payload.Z)
	// Only update the player's destination if the cell is valid and unoccupied
	if grid.IsValidCell(destination) {
		// We compare our new destination to our previous one
		previousDestination := state.player.GetGridDestination()
		// If the new destination is NOT the same one we already had
		if previousDestination != destination {
			// Calculate the shortest path from our current cell to our destination cell
			path := grid.AStar(state.player.Position, destination)

			// If the path is not empty
			if len(path) > 0 {
				// Set this path as our character's path
				state.player.SetGridPath(path)

				// Overwrite our previous destination
				state.player.SetGridDestination(destination)
			}
		}
	}
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
