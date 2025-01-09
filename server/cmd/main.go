package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"server/internal/server"
	"server/internal/server/clients"
)

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

	hub := server.NewHub()

	// Connect handler function that upgrades connection into a WebSocket connection
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		hub.Serve(clients.NewWebSocketClient, w, r)
	})

	// Starts the main hub on a goroutine
	go hub.Run()

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("Starting server on port %s", addr)

	// Starts the web server to listen for incoming TCP connections
	err := http.ListenAndServe(addr, nil)

	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
