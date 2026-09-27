class_name Hero
extends RefCounted

var cell := Vector2i(3, 3)
var facing := SimRules.FACING_DOWN
var direction := Vector2i.ZERO
var moving := false
var ticks_remaining := 0
var bombs_left := SimRules.STARTING_BOMBS
var bomb_level := SimRules.BOMB_LEVEL
var shield := SimRules.SHIELD_TICKS
var shielded_this_tick := false
var alive := true
var prev_fire := false


func pixel_position() -> Vector2:
	var origin := Vector2(cell) * float(SimRules.TILE_SIZE)
	if not moving:
		return origin
	var traveled := SimRules.FRAMES_PER_TILE - ticks_remaining
	return origin + Vector2(direction) * SimRules.MOVE_PER_TICK * float(traveled)


func rounded_cell() -> Vector2i:
	var px := pixel_position()
	var tile := float(SimRules.TILE_SIZE)
	return Vector2i(roundi(px.x / tile), roundi(px.y / tile))
