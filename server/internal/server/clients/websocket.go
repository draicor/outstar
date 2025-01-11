package clients

import (
	"log"
	"net/http"
	"server/internal/server"
	"server/internal/server/states"
	"server/pkg/packets"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"
)

type WebSocketClient struct {
	id          uint64               // Ephemeral ID for this connection
	connection  *websocket.Conn      // Websocket connection to the godot client
	hub         *server.Hub          // Hub that this client connected to
	zone        *server.Zone         // Zone that this client is at
	sendChannel chan *packets.Packet // Channel that holds packets to be sent to the client
	logger      *log.Logger
	state       server.ClientStateHandler // Knows in what state the client is in
	nickname    string                    // Seen by every other client
	DBTX        *server.DBTX
}

// Called from Hub.serve()
// Static function used to create a new WebSocket client from an HTTP connection (which is what Godot will use)
func NewWebSocketClient(hub *server.Hub, writer http.ResponseWriter, request *http.Request) (server.ClientInterfacer, error) {
	upgrader := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin:     func(_ *http.Request) bool { return true }, // TO FIX -> Validate request origin
	}

	// Upgrades the HTTP connection to a WebSocket connection
	conn, err := upgrader.Upgrade(writer, request, nil)

	// If we found an error creating the WebSocket connection, return the error
	if err != nil {
		return nil, err
	}

	// If no errors were found, create a new WebSocketClient
	client := &WebSocketClient{
		hub:         hub,                             // Entry point for all connected clients
		zone:        nil,                             // At creation, the client is not registered into any zones
		connection:  conn,                            // Underlying WebSocket connection
		sendChannel: make(chan *packets.Packet, 256), // Buffered channel of 256 packets, if full, drops packets
		logger:      log.New(log.Writer(), "", log.LstdFlags),
		DBTX:        hub.NewDBTX(),
	}

	return client, nil
}

// Returns the client's ID
func (c *WebSocketClient) Id() uint64 {
	return c.id
}

// Initializes the client's state within the server
func (c *WebSocketClient) Initialize(id uint64) {
	// We store the new id as this client's ID
	c.id = id
	// When a new client connects, we switch to the connected state
	c.SetState(&states.Connected{})
}

// Handles the packet that comes from the client
func (c *WebSocketClient) ProcessMessage(senderId uint64, payload packets.Payload) {
	c.state.HandleMessage(senderId, payload)
}

// Sends a message to the client
func (c *WebSocketClient) SocketSend(message packets.Payload) {
	c.SocketSendAs(message, c.id)
}

// This is useful when we want to forward a packet we received from another client
func (c *WebSocketClient) SocketSendAs(payload packets.Payload, senderId uint64) {
	select {
	// We queue messages up to send to the client
	case c.sendChannel <- &packets.Packet{
		SenderId: senderId,
		Payload:  payload,
	}:
	// If the client's channel is full, we drop the message and log a warning
	// This is to prevent the server from blocking waiting for this client
	default:
		c.logger.Printf("Client %d send channel full, dropping message: %T", c.id, payload)
	}
}

// Forward packet's payload to a specific client by ID
func (c *WebSocketClient) PassToPeer(payload packets.Payload, peerId uint64) {
	// If this client is currently in a zone
	if c.zone != nil {
		// We look for the peer in the current zone
		peer, found := c.zone.GetClient(peerId)
		if found {
			peer.ProcessMessage(c.id, payload)
		}

	} else {
		// We look for the peer in the server's map of clients
		peer, found := c.hub.GetClient(peerId)
		if found {
			peer.ProcessMessage(c.id, payload)
		}
	}
}

// Convenience function to queue a packet up to be passed to every client except the sender
func (c *WebSocketClient) Broadcast(payload packets.Payload) {
	// If this client is currently in a zone
	if c.zone != nil {
		// We send it to the broadcast channel of that zone
		c.zone.GetBroadcastChannel() <- &packets.Packet{
			SenderId: c.id,
			Payload:  payload,
		}

	} else {
		// We send it to the Hub's broadcast channel
		c.hub.GetBroadcastChannel() <- &packets.Packet{
			SenderId: c.id,
			Payload:  payload,
		}
	}
}

// Directly interfaces with the websocket from Godot
// Responsible for reading and processing messages from the Godot client
func (c *WebSocketClient) ReadPump() {
	// We defer closing this connection so we can clean up if an error occurs or the loop breaks
	defer func() {
		c.Close("Read pump closed")
	}()

	// Infinite loop
	for {
		_, data, err := c.connection.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				c.logger.Printf("error: %v", err)
			}
			break
		}

		// We convert raw bytes into a packet
		packet := &packets.Packet{}
		err = proto.Unmarshal(data, packet)
		// If an error occurs, we drop the packet and try to read the next one
		if err != nil {
			c.logger.Printf("Error unmarshaling data: %v", err)
			continue
		}

		// Allows the client to lazily not set the sender ID when sending a message to the server
		if packet.SenderId == 0 {
			packet.SenderId = c.id
		}

		c.ProcessMessage(packet.SenderId, packet.Payload)
	}
}

// Directly interfaces with the websocket from Godot
// Responsible for reading packets we've queued in the send channel, serialize and send them to the Godot client
func (c *WebSocketClient) WritePump() {
	// We defer closing this connection so we can clean up if an error occurs or the loop breaks
	defer func() {
		c.Close("Write pump closed")
	}()

	// Go over every message in the client's send channel
	for packet := range c.sendChannel {
		// Create a binary writer since Protobuf messages are binary
		writer, err := c.connection.NextWriter(websocket.BinaryMessage)
		// If we find an error, break out of this loop
		if err != nil {
			c.logger.Printf("Error getting writer for %T packet, closing client: %v", packet.Payload, err)
			return
		}

		// We convert the packet into raw bytes
		data, marshallErr := proto.Marshal(packet)
		// If we fail to serialize, we drop the packet and read the next one
		if marshallErr != nil {
			c.logger.Printf("Error marshalling %T packet, dropping: %v", packet.Payload, marshallErr)
			continue
		}

		// We write the data to the websocket
		_, writeErr := writer.Write(data)

		// If we fail to write this data to the websocket, we drop the packet and read the next one
		if writeErr != nil {
			c.logger.Printf("Error writing %T packet: %v", packet.Payload, writeErr)
			continue
		}

		// Append a newline to the end of every message
		writer.Write([]byte{'\n'})

		// There can be at most, one open writer per connection, so we try to close this writer
		closeErr := writer.Close()
		if closeErr != nil {
			c.logger.Printf("Error closing writer, dropping %T packet: %v", packet.Payload, closeErr)
			continue
		}
	}
}

// Responsible for cleaning up the client's connection and unregistering the client from the hub
func (c *WebSocketClient) Close(reason string) {
	c.logger.Printf("Closing client connection: %s", reason)

	// Broadcast to everyone that this client left before we remove it form the hub/zone
	c.Broadcast(packets.NewClientLeft(c.GetNickname()))

	// If we were at a zone, remove the client from this zone
	if c.zone != nil {
		c.zone.GetRemoveClientChannel() <- c

		// If we were at the Hub
	} else {
		// Remove the client from the Hub
		c.hub.GetRemoveClientChannel() <- c
	}

	// close the client's websocket connection
	c.connection.Close()

	// Remove the client's state after disconnection
	c.SetState(nil)

	// We check if the client's send channel is closed, if its not, we close it
	_, closed := <-c.sendChannel
	if !closed {
		close(c.sendChannel)
	}
}

func (c *WebSocketClient) SetState(state server.ClientStateHandler) {
	// State names are used for debugging purposes
	lastStateName := "None"

	// If our current state is valid
	if c.state != nil {
		// call the OnExit code for the current state
		lastStateName = c.state.Name()
		c.state.OnExit()
	}

	newStateName := "None"
	// If the new state is valid
	if state != nil {
		newStateName = state.Name()
	}

	// CHECK THIS
	// Probably a bug here, even if the state is INVALID, it will attempt to switch to it
	c.logger.Printf("Switching from state %s to %s", lastStateName, newStateName)
	c.state = state

	// If the client's new state is valid
	if c.state != nil {
		// Inject the client's data into the state and call the OnEnter code for the new state
		c.state.SetClient(c)
		c.state.OnEnter()
	}
}

// Returns the database transaction context from this client
func (c *WebSocketClient) GetDBTX() *server.DBTX {
	return c.DBTX
}

// Called after a client successfuly logins to store the nickname in memory
func (c *WebSocketClient) SetNickname(nickname string) {
	c.nickname = nickname
}

// Called by the server to form the packet it will broadcast
func (c *WebSocketClient) GetNickname() string {
	return c.nickname
}

// Moves the client to a new zone
func (c *WebSocketClient) SetZone(zone_id uint64) {
	log.Println("Triggering SetZone()")

	// If the client was at another zone
	if c.zone != nil {
		// Broadcast to everyone that this client left this zone!
		c.Broadcast(packets.NewClientLeft(c.GetNickname()))
		// Unregister the client from that zone
		c.zone.GetRemoveClientChannel() <- c

		// If the client was at the lobby
	} else {
		// Unregister the client from the hub
		// The underlying connection to the websocket will remain, but he won't
		// be sending packets directly to the hub, only to the zone hes at
		c.hub.GetRemoveClientChannel() <- c
	}

	// The Hub has a reference to all available zones
	zone, found := c.hub.GetZone(zone_id)

	// If the zone is already created
	if found {
		// Save a reference to the pointer to the zone this client is at
		c.zone = &zone
		// Register the client to the new zone
		c.zone.GetAddClientChannel() <- c
		// Broadcast to everyone that this client joined
		c.Broadcast(packets.NewClientEntered(c.GetNickname()))

	} else { // If the zone doesn't exist
		// create one!
		zone = *server.CreateZone(zone_id)

		// Save a reference to the pointer to the zone this client is at
		c.zone = &zone

		// Send the new zone to the Hub so it can register it and start it
		c.hub.AddZoneChannel <- *c.zone

		// Register the client to the new zone
		c.zone.GetAddClientChannel() <- c
		// Broadcast to everyone that this client joined
		c.Broadcast(packets.NewClientEntered(c.GetNickname()))
	}

}

/*
func (c *WebSocketClient) LeaveZone() {

	// If the client leaves a zone, he goes back to the hub again!

*/
