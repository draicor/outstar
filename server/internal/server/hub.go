package server

import (
	"log"
	"net/http"
	"server/pkg/packets"
)

// A structure for the connected client to interface with the hub
type ClientInterfacer interface {
	// Returns the client's ID
	Id() uint64

	// Handles the client's message
	ProcessMessage(senderId uint64, message packets.Payload)

	// Sets the client's ID
	Initialize(id uint64)

	// Puts data from the client into the write pump
	SocketSend(message packets.Payload)

	// Puts data from another client in the write pump
	SocketSendAs(message packets.Payload, senderId uint64)

	// Forward message to another client for processing
	PassToPeer(message packets.Payload, peerId uint64)

	// Forward message to all other clients for processing
	Broadcast(message packets.Payload)

	// Pump data from the connected socket directly to the client
	ReadPump()

	// Pump data from the client directly to the connected socket
	WritePump()

	// Close the client's connection and cleanup
	Close(reason string)
}

// The hub is the central point of communication between all connected clients
type Hub struct {
	// Map of all the connected clients
	Clients map[uint64]ClientInterfacer

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChannel chan *packets.Packet

	// Clients in this channel will be registered to the hub
	RegisterChannel chan ClientInterfacer

	// Clients in this channel will be unregistered from the hub
	UnregisterChannel chan ClientInterfacer
}

// Creates a new empty hub object
func NewHub() *Hub {
	return &Hub{
		Clients:           make(map[uint64]ClientInterfacer),
		BroadcastChannel:  make(chan *packets.Packet),
		RegisterChannel:   make(chan ClientInterfacer),
		UnregisterChannel: make(chan ClientInterfacer),
	}
}

// Listens for messages on each channel
func (h *Hub) Run() {
	log.Println("Awaiting new client connections...")

	// Infinite for loop
	for {
		// If there is no default case, the "select" statement blocks
		// until at least one of the communications can proceed
		select {
		// If we get a new client, register it to the hub
		case client := <-h.RegisterChannel:
			client.Initialize(uint64(len(h.Clients))) // FIX THIS, THIS WILL CAUSE BUGS
		// If a client disconnects, remove him from the hub
		case client := <-h.UnregisterChannel:
			h.Clients[client.Id()] = nil
		// If we get a packet from the broadcast channel
		case packet := <-h.BroadcastChannel:
			// Go over every registered client in the hub
			for id, client := range h.Clients {
				// Check that the sender does not send the message to itself
				if id != packet.SenderId {
					client.ProcessMessage(packet.SenderId, packet.Payload)
				}
			}
		}
	}
}

// Creates a client for the new connection and begins the concurrent read and write pumps
func (h *Hub) Serve(getNewClient func(*Hub, http.ResponseWriter, *http.Request) (ClientInterfacer, error), writer http.ResponseWriter, request *http.Request) {
	log.Println("New client connected from", request.RemoteAddr)

	// Executes the function that was passed as a parameter
	client, err := getNewClient(h, writer, request)

	if err != nil {
		log.Printf("Error obtaining client for new connection: %v\n", err)
		return
	}

	// Send the client to the register channel
	h.RegisterChannel <- client

	// Reads messages from the outbounds messages channel and writes them to the websocket
	go client.WritePump()
	// Reads messages from the websocket and process them
	go client.ReadPump()
}
