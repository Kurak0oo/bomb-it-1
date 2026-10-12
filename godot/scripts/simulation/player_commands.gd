class_name PlayerCommands
extends RefCounted

# One command slot per hero per simulation tick. Input adapters produce these
# values without talking to heroes. bomb_requested means held ordinary fire;
# edges are separate so future special weapons can preserve key-up gating.
var direction := Vector2i.ZERO
var bomb_requested := false
var bomb_pressed := false
var bomb_released := false


func request_direction(dir: Vector2i) -> void:
	direction = dir


func request_bomb() -> void:
	bomb_requested = true


# Original key order is left, up, right, down. The first held key wins. No diagonal.
static func priority_direction(left: bool, up: bool, right: bool, down: bool) -> Vector2i:
	if left:
		return Vector2i.LEFT
	elif up:
		return Vector2i.UP
	elif right:
		return Vector2i.RIGHT
	elif down:
		return Vector2i.DOWN
	return Vector2i.ZERO


