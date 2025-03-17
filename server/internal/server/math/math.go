package math

// Returns the absolute value of an integer
func Absolute(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

// Returns the minimum value among two integers
func Minimum(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Clamps the angle provided to fixed 45° ranges and within a 0-360 degrees range.
func ClampAngle(angle uint64) uint64 {
	if angle <= 23 {
		return 0
	} else if angle > 23 && angle <= 68 {
		return 45
	} else if angle > 68 && angle <= 113 {
		return 90
	} else if angle > 113 && angle <= 158 {
		return 135
	} else if angle > 158 && angle <= 203 {
		return 180
	} else if angle > 203 && angle <= 248 {
		return 225
	} else if angle > 248 && angle <= 293 {
		return 270
	} else if angle > 293 && angle <= 338 {
		return 315
	} else {
		return 0
	}
}

/* Radians to Angles
 * To convert degrees to radians, multiply the number of degrees by π/180
 * 0       -> 0°   North
 * 0.78    -> 45°  North West
 * 1.57    -> 90°  West
 * 2.35    -> 135° South West
 * 3.14    -> 180° South
 * 3.92    -> 225° South East
 * 4.71    -> 270° East
 * 5.49    -> 315° North East
 * > 6 = 0 -> 360° North
 */

// Accepts an angle in a 0-360 range and turn it into a float, then returns it
func DegreesToRadians(angle uint64) float64 {
	// We take the angle and clamp it into one of our 8 directions
	clampedAngle := ClampAngle(angle)
	// Then we switch based on the resulting angle and return the radian value
	switch clampedAngle {
	case 0: // North
		return 0
	case 45: // North West
		return 0.78
	case 90: // West
		return 1.57
	case 135: // South West
		return 2.35
	case 180: // South
		return 3.14
	case 225: // South East
		return 3.92
	case 270: // East
		return 4.71
	case 315: // North East
		return 5.49
	}

	// If it gets this far, return 0 (North)
	return 0
}
