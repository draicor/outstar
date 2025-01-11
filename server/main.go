package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"net/http"
	"server/internal/server"
	"server/internal/server/clients"

	_ "embed" // allows the use of the go:embed directive

	_ "modernc.org/sqlite" // registers itself with the sql package
)

// Embed the database schema to be used when creating the database tables
// the go:embed directive tells the compiler to include the contents of the
// schema.sql file in the binary when it is built, so we can access it at runtime.

//go:embed internal/server/db/config/schema.sql
var schemaGenSql string

// ADD A VERSION VARIABLE THAT SHOULD MATCH WITH THE CLIENT VARIABLE
// The client should send this variable upon connection attempt and it
// should match with the server's version to allow connection!

var (
	port = flag.Int("port", 31591, "Port to listen on")
)

// Generic TCP server
func main() {
	// Reads the OS command-line flags
	flag.Parse()

	// This generates the db.sqlite file if it doesn't exists
	log.Println("Connecting to the database...")
	database, err := sql.Open("sqlite", "internal/server/db/db.sqlite")
	if err != nil {
		log.Fatal(err)
	}
	// Query that doesn't return any rows to test the database connection
	_, err = database.ExecContext(context.Background(), schemaGenSql)
	if err != nil {
		log.Fatal(err)
	}

	// Spawn the main hub that will take new websocket connections
	hub := server.CreateHub(database)

	// Connect handler function that upgrades connection into a WebSocket connection
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		hub.Serve(clients.NewWebSocketClient, w, r)
	})

	// Starts the main hub on a goroutine
	go hub.Start()

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("Server running on port %s", addr)

	// Starts the web server to listen for incoming TCP connections
	err = http.ListenAndServe(addr, nil)

	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
