class_name SimRules
extends Object

# Recovered from Sprite 564. vLevel 6 is frames per tile, not pixels per frame.
const TILE_SIZE := 30
const FRAMES_PER_TILE := 6
const SIMULATION_FPS := 35.0
const MOVE_PER_TICK := TILE_SIZE / float(FRAMES_PER_TILE)

const COLUMNS := 15
const ROWS := 13
const GAME_ORIGIN := Vector2(93.1, 5.2)

const FUSE_TICKS := 60
const LINGER_TICKS := 10
const FADE_STEP := 20
const FADE_REMOVE_BELOW := 5
const SHIELD_TICKS := 60
const BOMB_LEVEL := 1
const STARTING_BOMBS := 1
const BRICK_POP_TICKS := 11

const SPAWN := Vector2i(3, 3)
const FACING_DOWN := 3


static func direction(index: int) -> Vector2i:
	match index:
		0:
			return Vector2i.LEFT
		1:
			return Vector2i.UP
		2:
			return Vector2i.RIGHT
		3:
			return Vector2i.DOWN
	return Vector2i.ZERO


static func direction_index(dir: Vector2i) -> int:
	if dir == Vector2i.LEFT:
		return 0
	if dir == Vector2i.UP:
		return 1
	if dir == Vector2i.RIGHT:
		return 2
	if dir == Vector2i.DOWN:
		return 3
	return -1


# Flash rotation (directionIndex + 2) * 90. Godot 2D positive rotation is clockwise too.
static func flame_degrees(index: int) -> float:
	return [180.0, 270.0, 0.0, 90.0][index]
