package server

import (
	"log"
	"server/internal/server/objects"
	"server/pkg/packets"
)

// A room is a central point of communication between the connected clients within it
type Room struct {
	Id uint64 // Ephemeral ID assigned by the Hub at creation

	// Map of all the connected clients inside this room
	Clients *objects.SharedCollection[ClientInterfacer]

	// Players connected to this room
	PlayersOnline uint64

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChannel chan *packets.Packet

	// Clients received in this channel will be added to this room
	AddClientChannel chan ClientInterfacer

	// Clients received in this channel will be removed from this room
	RemoveClientChannel chan ClientInterfacer
}

// Returns this room's ID
func (r *Room) GetId() uint64 {
	return r.Id
}

// Sets the ID for this room after creation
func (r *Room) SetId(roomId uint64) {
	r.Id = roomId
}

// Creates a new room
func CreateRoom() *Room {
	return &Room{
		Clients:             objects.NewSharedCollection[ClientInterfacer](),
		BroadcastChannel:    make(chan *packets.Packet),
		AddClientChannel:    make(chan ClientInterfacer),
		RemoveClientChannel: make(chan ClientInterfacer),
	}
}

// Listens for packets on each channel
func (r *Room) Start() {
	log.Println("Room", r.Id, "created...")

	// Infinite for loop
	for {
		// If there is no default case, the "select" statement blocks
		// until at least one of the communications can proceed
		select {

		// If we get a new client, add it to this room
		case client := <-r.AddClientChannel:
			// WE HAVE TO PASS THE SAME ID AS THE HUB ID!!!
			r.Clients.Add(client, client.GetId()) // CAUTION HERE <-
			r.PlayersOnline++
		// If a client leaves, remove him from this room

		case client := <-r.RemoveClientChannel:
			r.Clients.Remove(client.GetId())
			r.PlayersOnline--
		// If we get a packet from the broadcast channel

		case packet := <-r.BroadcastChannel:
			// Go over every registered client in this room
			r.Clients.ForEach(func(id uint64, client ClientInterfacer) {
				// Check that the sender does not send the message to itself
				if client.GetId() != packet.SenderId {
					// If the client is not idling at the login/register screen
					if client.GetNickname() != "" {
						client.ProcessMessage(packet.SenderId, packet.Payload)
					}
				}
			})
		}
	}
}

// Retrieves the client (if found) in the Clients collection
func (r *Room) GetClient(id uint64) (ClientInterfacer, bool) {
	return r.Clients.Get(id)
}

// Returns the channel that can broadcast packets
func (r *Room) GetBroadcastChannel() chan *packets.Packet {
	return r.BroadcastChannel
}

// Returns the channel that registers new clients
func (r *Room) GetAddClientChannel() chan ClientInterfacer {
	return r.AddClientChannel
}

// Returns the channel that removes clients
func (r *Room) GetRemoveClientChannel() chan ClientInterfacer {
	return r.RemoveClientChannel
}

// Returns the number of players inside this room
func (r *Room) GetPlayersOnline() uint64 {
	return r.PlayersOnline
}
