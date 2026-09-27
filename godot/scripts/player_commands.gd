class_name PlayerCommands
extends RefCounted

# One command slot per simulation tick. Keyboard and, later, the touch joystick
# both call request_direction / request_bomb. Neither talks to the hero directly.
var direction := Vector2i.ZERO
var bomb_requested := false


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


func poll_keyboard() -> void:
	request_direction(priority_direction(
		Input.is_action_pressed("move_left"),
		Input.is_action_pressed("move_up"),
		Input.is_action_pressed("move_right"),
		Input.is_action_pressed("move_down"),
	))
	if Input.is_action_pressed("place_bomb"):
		request_bomb()
	else:
		bomb_requested = false
