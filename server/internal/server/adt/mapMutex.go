package adt

import "sync"

// Generic thread-safe map of objects with auto-incrementings IDs
type MapMutex[T any] struct {
	objects map[uint64]T
	nextId  uint64
	mutex   sync.Mutex
}

// Constructor for the MapMutex that allows us to specify the initial capacity of the map
func NewMapMutex[T any](capacity ...int) *MapMutex[T] {
	var newMap map[uint64]T

	if len(capacity) > 0 {
		newMap = make(map[uint64]T, capacity[0])
	} else {
		newMap = make(map[uint64]T)
	}

	return &MapMutex[T]{
		objects: newMap,
		nextId:  1,
	}
}

// Adds an object to the map with the given ID (if provided) or the next available ID
// Returns the ID of the object added
func (s *MapMutex[T]) Add(obj T, id ...uint64) uint64 {
	// We lock the map while we are adding our object
	s.mutex.Lock()
	defer s.mutex.Unlock()

	thisId := s.nextId
	// If we provided a valid ID, we use it, if not, we use the next available ID
	if len(id) > 0 {
		thisId = id[0]
	}

	// Add the object to the map and increment the ID
	s.objects[thisId] = obj
	s.nextId++

	return thisId
}

// Removes an object from the map by ID, if it exists
func (s *MapMutex[T]) Remove(id uint64) {
	// We lock the map while we are deleting this object
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// If the ID is not found, it doesn't do anything
	delete(s.objects, id)
}

// Creates a copy of the map, then executes the callback function for each object in the copy
func (s *MapMutex[T]) ForEach(callback func(uint64, T)) {
	// Lock the map so no other goroutine modify it while we are iterating over it
	s.mutex.Lock()
	// Create a local copy of the map while holding the lock
	localCopy := make(map[uint64]T, len(s.objects))
	for id, obj := range s.objects {
		localCopy[id] = obj
	}

	// If the callback function takes a long time to execute, we don't want to hold the lock
	// for that long as it could block other goroutines from accessing the map,
	// so we unlock the map after creating the copy, and call the function for the copy instead
	s.mutex.Unlock()

	// Iterate over the local copy
	for id, obj := range localCopy {
		callback(id, obj)
	}
}

// Gets the object by ID, if it exists, otherwise nil
// Also returns a boolean indicating whether the object was found
func (s *MapMutex[T]) Get(id uint64) (T, bool) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	obj, found := s.objects[id]
	return obj, found
}

// Gets the approximate number of objects in the map (it doesn't lock the map)
func (s *MapMutex[T]) Len() int {
	return len(s.objects)
}
