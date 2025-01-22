package clients

import (
	"fmt"
	"log"
	"net/http"
	"server/internal/server"
	"server/internal/server/objects"
	"server/internal/server/states"
	"server/pkg/packets"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"
)

// This client data will be injected into every state on state changes,
// any data that should be kept in server memory should be stored in the
// WebSocketClient
type WebSocketClient struct {
	id          uint64               // Ephemeral ID for this connection
	connection  *websocket.Conn      // Websocket connection to the godot client
	hub         *server.Hub          // Hub that this client connected to
	region      *server.Region       // Region that this client is at
	sendChannel chan *packets.Packet // Channel that holds packets to be sent to the client
	state       server.ClientState   // In what state the client is in
	character   *objects.Character   // The player's data is stored in his character
	dbtx        *server.DBTX         // <- FIX dependency
	logger      *log.Logger
}

// Called from Hub.serve()
// Static function used to create a new WebSocket client from an HTTP connection (which is what Godot will use)
func NewWebSocketClient(hub *server.Hub, writer http.ResponseWriter, request *http.Request) (server.Client, error) {
	upgrader := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin:     func(_ *http.Request) bool { return true }, // FIX -> Validate request origin
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
		region:      nil,                             // Before login, the client's region is nil
		connection:  conn,                            // Underlying WebSocket connection
		sendChannel: make(chan *packets.Packet, 256), // Buffered channel of 256 packets, if full, drops packets
		logger:      log.New(log.Writer(), "", log.LstdFlags),
		dbtx:        hub.NewDBTX(), // <- FIX dependency
	}

	return client, nil
}

// Character get/set
func (c *WebSocketClient) GetCharacter() *objects.Character {
	return c.character
}
func (c *WebSocketClient) SetCharacter(character *objects.Character) {
	c.character = character
}

// Returns the Hub this client is connected to
func (c *WebSocketClient) GetHub() *server.Hub {
	return c.hub
}

// Region get/set
func (c *WebSocketClient) GetRegion() *server.Region {
	return c.region
}
func (c *WebSocketClient) SetRegion(region *server.Region) {
	c.region = region
}

// Returns the client's ID
func (c *WebSocketClient) GetId() uint64 {
	return c.id
}

// Initializes the client's state within the server
func (c *WebSocketClient) Initialize(id uint64) {
	// We store the new id as this client's ID
	c.id = id
	// Improve the details of the logged data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", c.GetId(), "WebSocket")
	c.logger.SetPrefix(prefix)

	// When a new client connects, we switch to the connected state
	c.SetState(&states.Connected{})
}

// Handles the packet that comes from the client
func (c *WebSocketClient) ProcessPacket(senderId uint64, payload packets.Payload) {
	c.state.HandlePacket(senderId, payload)
}

// Sends a message to the client
func (c *WebSocketClient) SendPacket(payload packets.Payload) {
	c.SendPacketAs(c.id, payload)
}

// This is useful when we want to forward a packet we received from another client
func (c *WebSocketClient) SendPacketAs(senderId uint64, payload packets.Payload) {
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
// Note: only works if both clients are in the same region!
func (c *WebSocketClient) RelayPacket(peerId uint64, payload packets.Payload) {
	// If this client is currently in a region
	if c.region != nil {
		// We look for the peer in the current region
		peer, found := c.region.GetClient(peerId)
		if found {
			peer.ProcessPacket(c.id, payload)
		}
	}
}

// Convenience function to queue a packet up to be passed to every client except the sender
// Note: only works if the client is logged in and in a region
func (c *WebSocketClient) Broadcast(payload packets.Payload) {
	// If this client is currently in a region
	if c.region != nil {
		// We send it to the broadcast channel of that region
		c.region.BroadcastChannel <- &packets.Packet{
			SenderId: c.id,
			Payload:  payload,
		}
	}
}

// Starts reading and processing packets from the Godot client
func (c *WebSocketClient) StartReadPump() {
	// We defer closing this connection so we can clean up if an error occurs or the loop breaks
	defer func() {
		c.Close("disconnected")
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

		// TO DO ->
		// Replace this with a tickChannel so the hub/lobby/region process this by tick
		c.ProcessPacket(packet.SenderId, packet.Payload)
	}
}

// Starts reading packets we've queued in the send channel, serialize and send them to the Godot client
func (c *WebSocketClient) StartWritePump() {
	// We defer closing this connection so we can clean up if an error occurs or the loop breaks
	defer func() {
		c.Close("disconnected")
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

// Cleans up the client's connection and unregisters the client from the server
func (c *WebSocketClient) Close(reason string) {
	if c.GetCharacter() != nil {
		// Server logging
		c.logger.Printf("%s %s", c.character.Name, reason)
		// Broadcast to everyone that this client left before we remove it from the hub/region
		c.Broadcast(packets.NewClientLeft(c.character.Name))

	} else { // If the client connected to the server but never logged in
		c.logger.Println("Client", reason)
	}

	// If we were at a region, remove the client from this region
	if c.region != nil {
		c.region.RemoveClientChannel <- c
	}

	// Remove the client from the Hub
	c.hub.RemoveClientChannel <- c

	// Remove the client's state before disconnection
	c.SetState(nil)

	// close the client's websocket connection
	c.connection.Close()

	// We check if the client's send channel is closed, if its not, we close it
	_, closed := <-c.sendChannel
	if !closed {
		close(c.sendChannel)
	}
}

func (c *WebSocketClient) SetState(state server.ClientState) {
	// State names are used for debugging purposes
	lastStateName := "None"

	// If our current state is valid
	if c.state != nil {
		// call the OnExit code for the current state
		lastStateName = c.state.GetName()
		c.state.OnExit()
	}

	newStateName := "None"
	// If the new state is valid
	if state != nil {
		newStateName = state.GetName()
	}

	// Server logging
	if c.character != nil {
		c.logger.Printf("%s switched from %s to %s", c.character.Name, lastStateName, newStateName)
	}

	// Replace the previous state with the new one inside this client
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
	return c.dbtx
}
