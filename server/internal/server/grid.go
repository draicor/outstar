package server

import (
	"server/internal/server/objects"
)

type Grid struct {
	max_width  uint64
	max_height uint64
	length     uint64                   // 2d array length as a 1d array (max_width * max_height)
	grid       map[uint64]*objects.Cell // A hash map between the 1d index and each cell in the 2d world
}
