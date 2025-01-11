package server

import (
	"database/sql"
	"log"
	"server/internal/server/objects"
	"server/pkg/packets"
)

// A zone is a central point of communication between the connected clients within it
type Zone struct {
	Id uint64 // Ephemeral ID assigned by the Hub at creation

	// Map of all the connected clients inside this zone
	Clients *objects.SharedCollection[ClientInterfacer]

	// Players connected counter
	PlayersOnline uint16

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChannel chan *packets.Packet

	// Clients received in this channel will be added to this zone
	AddClientChannel chan ClientInterfacer

	// Clients received in this channel will be removed from this zone
	RemoveClientChannel chan ClientInterfacer

	// Database connection pool
	DatabasePool *sql.DB
}

// Returns this zone's ID
func (z *Zone) GetId() uint64 {
	return z.Id
}

// Creates a new zone, we have to pass a valid DB connection FOR NOW
func CreateZone(databasePool *sql.DB, id uint64) *Zone {
	return &Zone{
		Id:                  id,
		Clients:             objects.NewSharedCollection[ClientInterfacer](),
		BroadcastChannel:    make(chan *packets.Packet),  // unbuffered channel
		AddClientChannel:    make(chan ClientInterfacer), // unbuffered channel
		RemoveClientChannel: make(chan ClientInterfacer), // unbuffered channel
		DatabasePool:        databasePool,
	}
}

// Listens for packets on each channel
func (z *Zone) Start() {
	log.Println("Zone", z.Id, "instatiated...")

	// Infinite for loop
	for {
		// If there is no default case, the "select" statement blocks
		// until at least one of the communications can proceed
		select {
		// If we get a new client, add it to this zone
		case client := <-z.AddClientChannel:
			z.Clients.Add(client)
		// If a client leaves, remove him from this zone
		case client := <-z.RemoveClientChannel:
			z.Clients.Remove(client.Id())
		// If we get a packet from the broadcast channel
		case packet := <-z.BroadcastChannel:
			// Go over every registered client in this zone
			z.Clients.ForEach(func(clientId uint64, client ClientInterfacer) {
				// Check that the sender does not send the message to itself
				if clientId != packet.SenderId {
					client.ProcessMessage(packet.SenderId, packet.Payload)
				}
			})
		}
	}
}

// Retrieves the client (if found) in the Clients collection
func (z *Zone) GetClient(id uint64) (ClientInterfacer, bool) {
	return z.Clients.Get(id)
}

// Returns the channel that can broadcast packets
func (z *Zone) GetBroadcastChannel() chan *packets.Packet {
	return z.BroadcastChannel
}

// Returns the channel that registers new clients
func (z *Zone) GetAddClientChannel() chan ClientInterfacer {
	return z.AddClientChannel
}

// Returns the channel that removes clients
func (z *Zone) GetRemoveClientChannel() chan ClientInterfacer {
	return z.RemoveClientChannel
}
