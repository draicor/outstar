package server

import (
	"fmt"
	"log"
	"server/internal/server/objects"
	"server/pkg/packets"
)

// A room is a central point of communication between the connected clients within it
type Room struct {
	// Ephemeral ID assigned by the Hub at creation
	Id uint64

	// Map of all the connected clients inside this room
	Clients *objects.SharedCollection[ClientInterfacer]

	// Master of this room
	RoomMaster string

	// Players connected to this room
	PlayersOnline uint64

	// Max players allowed to join this room as participants
	MaxPlayers uint64

	// Map of slot IDs and clientInterfacers in each slot
	Slots map[uint64]ClientInterfacer

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChannel chan *packets.Packet

	// Clients received in this channel will be added to this room
	AddClientChannel chan ClientInterfacer

	// Clients received in this channel will be removed from this room
	RemoveClientChannel chan ClientInterfacer

	logger *log.Logger
}

// Returns this room's ID
func (r *Room) GetId() uint64 {
	return r.Id
}

// Sets the ID for this room after creation
func (r *Room) SetId(roomId uint64) {
	r.Id = roomId
	// Improve the details of the logged data in the server console
	prefix := fmt.Sprintf("[Room %d]: ", r.GetId())
	r.logger.SetPrefix(prefix)
}

// Static function that creates a new room
func CreateRoom(maxPlayers uint64) *Room {
	return &Room{
		PlayersOnline:       0,
		MaxPlayers:          maxPlayers,
		Slots:               make(map[uint64]ClientInterfacer, maxPlayers),
		Clients:             objects.NewSharedCollection[ClientInterfacer](),
		BroadcastChannel:    make(chan *packets.Packet),
		AddClientChannel:    make(chan ClientInterfacer),
		RemoveClientChannel: make(chan ClientInterfacer),
		logger:              log.New(log.Writer(), "", log.LstdFlags),
	}
}

// Listens for packets on each channel
func (r *Room) Start() {
	r.logger.Println("Listening for packets...")

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
			// this is how you occupy a slot mapVariable[key] = value
			// r.Slots[0] = client

			// this is how you delete a slot delete(mapVariable, key)
			// delete(r.Slots, 0)

			// this is how you get a single value in the map mapVariable[key]
			// r.Slots[0]

			// this is how you get the total occupied slots len(mapVariable)
			// uint64(len(r.Slots))

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
					client.ProcessMessage(packet.SenderId, packet.Payload)
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

// Returns the maximum number of players that can participate in this match
func (r *Room) GetMaxPlayers() uint64 {
	return r.MaxPlayers
}

// Updates the capacity of this room
func (r *Room) SetMaxPlayers(newMaxPlayers uint64) {
	// If the new capacity is lower than the current number of players inside, ignore this
	if newMaxPlayers < r.PlayersOnline {
		return
	}
	// If the new capacity is the same as the previous one, ignore this
	if newMaxPlayers == r.MaxPlayers {
		return
	}

	r.MaxPlayers = newMaxPlayers
}
