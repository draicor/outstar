package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"server/internal/server"
	"server/internal/server/clients"
)

var (
	port = flag.Int("port", 31591, "Port to listen on")
)

// Generic TCP server
func main() {
	// Reads the OS command-line flags
	flag.Parse()

	hub := server.NewHub()

	// Handler that upgrades to a WebSocket connection
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		hub.Serve(clients.NewWebSocketClient, w, r)
	})

	// Starts the server
	go hub.Run()

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("Starting server on port %s", addr)

	err := http.ListenAndServe(addr, nil)

	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

/*
	packet := &packets.Packet{
		SenderId: 1,
		Payload:  packets.NewChatMessage("Hello, world"),
	}

	fmt.Println(packet)

	// Determines the type of payload at runtime
	switch packet.GetPayload().(type) {
	case *packets.Packet_ChatMessage:
		fmt.Println("Its a chat message.")
	case *packets.Packet_ClientId:
		fmt.Println("It's a client ID message.")
	case nil:
		fmt.Println("The payload was not set.")
	default:
		fmt.Println("Invalid payload.")
	}

	data := []byte{8, 1, 18, 14, 10, 12, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 33}
	packet := &packets.Packet{}
	proto.Unmarshal(data, packet)
	fmt.Println(packet)
*/
