package server

import (
	"fmt"
	"log"
	"math/rand"
	"server/internal/server/adt"
	"server/internal/server/pathfinding"
	"server/pkg/packets"
)

// A region is a central point of communication between the connected clients within it
type Region struct {
	// ID assigned by the Hub at creation
	Id uint64

	// Map of all the connected clients inside this region
	Clients *adt.MapMutex[Client]

	// Name of this region
	Name string

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChannel chan *packets.Packet

	// Clients received in this channel will be added to this room
	AddClientChannel chan Client

	// Clients received in this channel will be removed from this room
	RemoveClientChannel chan Client

	// 2D Grid map for this region
	grid pathfinding.Grid

	// List of cells where players can respawn
	Respawners []*pathfinding.Cell

	logger *log.Logger
}

// Returns this region's ID
func (r *Region) GetId() uint64 {
	return r.Id
}

// Sets the ID for this region after creation
func (r *Region) SetId(id uint64) {
	r.Id = id
	// Improve the details of the logged data in the server console
	prefix := fmt.Sprintf("[%s]: ", r.Name)
	r.logger.SetPrefix(prefix)
}

// Region get/set
func (r *Region) GetGrid() pathfinding.Grid {
	return r.grid
}
func (r *Region) SetGrid(grid pathfinding.Grid) {
	r.grid = grid
}

// Static function that creates a new region
func CreateRegion(name string, gameMap string, gridWidth uint64, gridHeight uint64) *Region {
	return &Region{
		Name:                name,
		Clients:             adt.NewMapMutex[Client](),
		BroadcastChannel:    make(chan *packets.Packet),
		AddClientChannel:    make(chan Client),
		RemoveClientChannel: make(chan Client),
		grid:                *pathfinding.CreateGrid(gridWidth, gridHeight),
		logger:              log.New(log.Writer(), "", log.LstdFlags),
	}
}

// Listens for packets on each channel
func (r *Region) Start() {
	// Log into the console which region this is and whats its grid size
	grid := r.GetGrid()
	r.logger.Printf("%s region [%d] created (%dx%d)...", r.Name, r.GetId(), grid.GetMaxWidth(), grid.GetMaxHeight())

	// Infinite for loop
	for {
		// If there is no default case, the "select" statement blocks
		// until at least one of the communications can proceed
		select {

		// If we get a new client, add it to this region
		case client := <-r.AddClientChannel:
			// WE HAVE TO PASS THE SAME ID AS THE HUB ID!!!
			r.Clients.Add(client, client.GetId()) // CAUTION HERE <-

		// If a client leaves
		case client := <-r.RemoveClientChannel:
			// Get the player's position in the grid
			cell := client.GetPlayerCharacter().GetGridPosition()
			if cell != nil {
				// Remove the player from the grid
				grid := r.GetGrid()
				grid.SetObject(cell, nil)
			}

			// Remove him from this region
			r.Clients.Remove(client.GetId())

		// If we get a packet from the broadcast channel
		case packet := <-r.BroadcastChannel:
			// Go over every registered client in this room
			r.Clients.ForEach(func(id uint64, client Client) {
				// Check that the sender does not send the packet to itself
				if client.GetId() != packet.SenderId {
					client.ProcessPacket(packet.SenderId, packet.Payload)
				}
			})
		}
	}
}

// Retrieves the client (if found) in the Clients collection
func (r *Region) GetClient(id uint64) (Client, bool) {
	return r.Clients.Get(id)
}

// Checks if the desired coordinate is in the respawners list
// If yes, use that coordinate
// If no, choose a random respawner from the list
// If no respawners are defined, fall back to (0,0)
// Then find the nearest available cell from the chosen coordinate
func (r *Region) RespawnPlayer(client Client, desiredPosition *pathfinding.Cell) error {
	player := client.GetPlayerCharacter()
	// Get the player's current position
	deathPosition := player.GetGridPosition()

	// Reset player stats
	player.Respawn()

	// Get the grid
	grid := r.GetGrid()

	// Remove player from server grid immediately
	grid.SetObject(deathPosition, nil)

	// Determine respawn cell based on respawners
	var respawnCell *pathfinding.Cell

	if desiredPosition != nil {
		// Check if desired position is in respawners list
		for _, respawner := range r.Respawners {
			// If we find a match, assign that desired position as our respawn cell
			if respawner.X == desiredPosition.X && respawner.Z == desiredPosition.Z {
				respawnCell = desiredPosition
				break
			}
		}
	}

	// If desired position is not valid or not provided, choose a random respawner
	if respawnCell == nil {
		// If this region has valid spawners
		if len(r.Respawners) > 0 {
			// Choose a random respawner
			randIndex := rand.Intn(len(r.Respawners))
			respawnCell = r.Respawners[randIndex]
		} else {
			// Fallback to (0,0) if no respawners defined
			respawnCell = grid.LocalToMap(0, 0)
		}
	}

	// Find the nearest available cell from the chosen respawn cell
	playerSpawnCell := grid.GetSpawnCell(respawnCell.X, respawnCell.Z)

	// If no cell was found in this region, return error
	if playerSpawnCell == nil {
		return fmt.Errorf("no respawn location available in region %d", r.GetId())
	}

	// Place player at respawn location
	grid.SetObject(playerSpawnCell, player)
	player.SetGridPosition(playerSpawnCell)
	player.SetGridDestination(playerSpawnCell)

	// Create and broadcast respawn packet
	respawnPacket := packets.NewSpawnCharacter(client.GetId(), player)

	// Broadcast respawn to everyone in the region (including the respawning client)
	client.SendPacket(respawnPacket)
	client.Broadcast(respawnPacket)

	r.logger.Printf("Player %s respawned at (%d, %d)", player.Name, playerSpawnCell.X, playerSpawnCell.Z)

	return nil
}
