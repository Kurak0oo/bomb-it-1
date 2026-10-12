class_name HeroState
extends RefCounted

enum Controller { HUMAN, AI }

var id := 0
var character_id := 1
var controller := Controller.HUMAN
var bomb_capacity := SimRules.STARTING_BOMBS
var lives := 1
var speed_level := SimRules.FRAMES_PER_TILE
var step_duration := SimRules.FRAMES_PER_TILE
var glove := false
var armor := false
var special_weapon := ""
var special_count := 0
var fire_ready := true
var slow_ticks := 0
var stop_ticks := 0
var score := 0
# Read-only score-sheet breakdown; awards still happen once in the simulation.
var kill_score := 0
var destruction_score := 0
var time_score := 0
var bonus_score := 0
var walk_frame := 0
var death_ticks := 0
var death_position := Vector2.ZERO
var cell := Vector2i(3, 3)
var facing := SimRules.FACING_DOWN
var direction := Vector2i.ZERO
var moving := false
var ticks_remaining := 0
var bombs_available := SimRules.STARTING_BOMBS
var bomb_level := SimRules.BOMB_LEVEL
var shield := SimRules.SHIELD_TICKS
var shielded_this_tick := false
var alive := true
var prev_fire := false


func pixel_position() -> Vector2:
	if not alive:
		return death_position
	var origin := Vector2(cell) * float(SimRules.TILE_SIZE)
	if not moving:
		return origin
	var traveled := step_duration - ticks_remaining
	return origin + Vector2(direction) * SimRules.TILE_SIZE * float(traveled) / step_duration


func rounded_cell() -> Vector2i:
	var px := pixel_position()
	var tile := float(SimRules.TILE_SIZE)
	return Vector2i(roundi(px.x / tile), roundi(px.y / tile))
