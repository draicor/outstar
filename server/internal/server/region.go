package server

import (
	"fmt"
	"log"
	"server/internal/server/objects"
	"server/pkg/packets"
)

// A region is a central point of communication between the connected clients within it
type Region struct {
	// ID assigned by the Hub at creation
	Id uint64

	// Map of all the connected clients inside this region
	Clients *objects.MapMutex[ClientInterfacer]

	// Name of this region
	Name string

	// Map name for this region
	// TO FIX -> This should be an enum on both server and client with the same order
	GameMap string

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChannel chan *packets.Packet

	// Clients received in this channel will be added to this room
	AddClientChannel chan ClientInterfacer

	// Clients received in this channel will be removed from this room
	RemoveClientChannel chan ClientInterfacer

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

// Static function that creates a new region
func CreateRegion(name string, gameMap string) *Region {
	return &Region{
		Name:                name,
		GameMap:             gameMap,
		Clients:             objects.NewMapMutex[ClientInterfacer](),
		BroadcastChannel:    make(chan *packets.Packet),
		AddClientChannel:    make(chan ClientInterfacer),
		RemoveClientChannel: make(chan ClientInterfacer),
		logger:              log.New(log.Writer(), "", log.LstdFlags),
	}
}

// Listens for packets on each channel
func (r *Region) Start() {
	r.logger.Println("Region created...")

	// Infinite for loop
	for {
		// If there is no default case, the "select" statement blocks
		// until at least one of the communications can proceed
		select {

		// If we get a new client, add it to this region
		case client := <-r.AddClientChannel:
			// WE HAVE TO PASS THE SAME ID AS THE HUB ID!!!
			r.Clients.Add(client, client.GetId()) // CAUTION HERE <-

		// If a client leaves, remove him from this region
		case client := <-r.RemoveClientChannel:
			r.Clients.Remove(client.GetId())

		// If we get a packet from the broadcast channel
		case packet := <-r.BroadcastChannel:
			// Go over every registered client in this room
			r.Clients.ForEach(func(id uint64, client ClientInterfacer) {
				// Check that the sender does not send the packet to itself
				if client.GetId() != packet.SenderId {
					client.ProcessPacket(packet.SenderId, packet.Payload)
				}
			})
		}
	}
}

// Retrieves the client (if found) in the Clients collection
func (r *Region) GetClient(id uint64) (ClientInterfacer, bool) {
	return r.Clients.Get(id)
}
