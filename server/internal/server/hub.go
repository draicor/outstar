package server

import (
	"context"
	"log"
	"net/http"
	"server/internal/server/db"
	"server/internal/server/objects"
	"server/pkg/packets"

	_ "embed"

	"database/sql"

	_ "modernc.org/sqlite" // registers itself with the sql package
)

// Embed the database schema to be used when creating the database tables
// the go:embed directive tells the compiler to include the contents of the
// schema.sql file in the binary when it is built, so we can access it at runtime.

//go:embed db/config/schema.sql
var schemaGenSql string

// Each client interfacer will have its own database transaction context.
type DBTX struct {
	Ctx     context.Context
	Queries *db.Queries
}

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

	// Updates the state of this client
	SetState(newState ClientStateHandler)

	// Get reference to the database transaction context for this client
	GetDBTX() *DBTX
}

// A structure for a state machine to process the client's messages
type ClientStateHandler interface {
	Name() string

	// Inject the client into the state handler, so we can access the client's data
	SetClient(client ClientInterfacer)

	OnEnter()
	HandleMessage(senderId uint64, payload packets.Payload)

	// Cleanup the state handler
	OnExit()
}

// The hub is the central point of communication between all connected clients
type Hub struct {
	// Map of all the connected clients
	Clients *objects.SharedCollection[ClientInterfacer]

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChannel chan *packets.Packet

	// Clients in this channel will be registered to the hub
	RegisterChannel chan ClientInterfacer

	// Clients in this channel will be unregistered from the hub
	UnregisterChannel chan ClientInterfacer

	// Database connection pool
	dbPool *sql.DB
}

// Creates a new empty hub object
func NewHub() *Hub {
	// Attempt to open the db connection
	dbPool, err := sql.Open("sqlite", "db.sqlite")
	if err != nil {
		log.Fatal(err)
	}

	return &Hub{
		Clients:           objects.NewSharedCollection[ClientInterfacer](),
		BroadcastChannel:  make(chan *packets.Packet),
		RegisterChannel:   make(chan ClientInterfacer),
		UnregisterChannel: make(chan ClientInterfacer),
		dbPool:            dbPool,
	}
}

// Listens for packets on each channel
func (h *Hub) Run() {
	log.Println("Initializing database...")
	_, err := h.dbPool.ExecContext(context.Background(), schemaGenSql)
	if err != nil {
		log.Fatal(err)
	}

	log.Println("Awaiting client connections...")

	// Infinite for loop
	for {
		// If there is no default case, the "select" statement blocks
		// until at least one of the communications can proceed
		select {
		// If we get a new client, register it to the hub
		case client := <-h.RegisterChannel:
			// The Add method returns an ID, which we use to Initialize the WebSocket Client's ID
			client.Initialize(h.Clients.Add(client))
		// If a client disconnects, remove him from the hub
		case client := <-h.UnregisterChannel:
			h.Clients.Remove(client.Id())
		// If we get a packet from the broadcast channel
		case packet := <-h.BroadcastChannel:
			// Go over every registered client in the hub
			h.Clients.ForEach(func(clientId uint64, client ClientInterfacer) {
				// Check that the sender does not send the message to itself
				if clientId != packet.SenderId {
					client.ProcessMessage(packet.SenderId, packet.Payload)
				}
			})
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

// Creates a basic context and holds a reference to the SQL Queries generated by sqlc.
func (h *Hub) NewDBTX() *DBTX {
	return &DBTX{
		Ctx:     context.Background(),
		Queries: db.New(h.dbPool),
	}
}
