package states

import (
	"fmt"
	"log"
	"server/internal/server"
	"server/pkg/packets"
)

type Connected struct {
	client server.ClientInterfacer
	logger *log.Logger
}

func (c *Connected) Name() string {
	return "Connected"
}

func (c *Connected) SetClient(client server.ClientInterfacer) {
	c.client = client
	prefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), c.Name())
	c.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (c *Connected) OnEnter() {
	// A newly connected client will receive its own ID
	c.client.SocketSend(packets.NewClientId(c.client.Id()))
}

func (c *Connected) HandleMessage(senderId uint64, payload packets.Payload) {
	// If this message was sent by this client
	if senderId == c.client.Id() {
		// Check the type of packet
		switch payload.(type) {
		// chat_message packet
		case *packets.Packet_ChatMessage:
			// Broadcast it to everyone else
			c.client.Broadcast(payload)
		case *packets.Packet_Heartbeat:
			// Heartbeat received from the client
			c.client.SocketSend(packets.NewHeartbeat(true))
		case nil:
			// Ignore packet if not a valid payload type
		default:
			// Ignore packet if no payload was sent
		}

	} else {
		// If another client or the hub passed us this message, forward it to this client
		c.client.SocketSendAs(payload, senderId)
	}
}

func (c *Connected) OnExit() {
	// TO FIX -> We are not handling the close yet!
}
