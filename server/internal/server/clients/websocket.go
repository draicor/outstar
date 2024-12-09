package clients

import (
	"fmt"
	"log"
	"net/http"
	"server/internal/server"
	"server/pkg/packets"

	"github.com/gorilla/websocket"
)

type WebSocketClient struct {
	id          uint64
	connection  *websocket.Conn
	hub         *server.Hub          // Hub that created this client
	sendChannel chan *packets.Packet // Channel that holds packets to be sent to the client
	logger      *log.Logger
}

// Called from Hub.serve()
// Static function used to create a new websocket client from an HTTP connection (which is what Godot will use)
func NewWebSocketClient(hub *server.Hub, writer http.ResponseWriter, request *http.Request) (server.ClientInterfacer, error) {
	upgrader := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin:     func(_ *http.Request) bool { return true }, // FIX: Validate request origin
	}

	// Upgrades the HTTP connection to a websocket connection
	conn, err := upgrader.Upgrade(writer, request, nil)

	if err != nil {
		return nil, err
	}

	client := &WebSocketClient{
		hub:         hub,
		connection:  conn,
		sendChannel: make(chan *packets.Packet, 256), // Buffered channel that can hold up to 256 packets before it blocks
		logger:      log.New(log.Writer(), "Client unknown: ", log.LstdFlags),
	}

	return client, nil
}

// Returns the client's ID
func (c *WebSocketClient) Id() uint64 {
	return c.id
}

// Initializes the client connection
func (c *WebSocketClient) Initialize(id uint64) {
	c.id = id
	// Prefix our logger with with the client's ID for debugging
	c.logger.SetPrefix(fmt.Sprintf("Client %d: ", c.id))
}
