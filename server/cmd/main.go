package main

import (
	"fmt"
	"server/pkg/packets"

	"google.golang.org/protobuf/proto" // Marshal & Unmarshal packets
)

func main() {
	// [8 1 18 14 10 12 72 101 108 108 111 32 87 111 114 108 100 33]
	// [8 1 26 3 8 244 3]
	data := []byte{8, 1, 18, 14, 10, 12, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 33}
	packet := &packets.Packet{}
	proto.Unmarshal(data, packet)
	fmt.Println(packet)
}
