class_name KeyboardInput
extends RefCounted

var _blocked_directions: Dictionary = {}

func cancel() -> void:
	for id in 2:
		for direction_name in ["left", "up", "right", "down"]:
			var action := "p%d_%s" % [id + 1, direction_name]
			if Input.is_action_pressed(action):
				_blocked_directions[action] = true

func observe(event: InputEvent) -> void:
	# Releases may arrive while paused or on another screen, between polls.
	for action in _blocked_directions.keys():
		if event.is_action_released(action):
			_blocked_directions.erase(action)

func _direction_pressed(action: String) -> bool:
	var held := Input.is_action_pressed(action)
	if not held:
		_blocked_directions.erase(action)
	return held and not _blocked_directions.has(action)

# Edges are carried to the simulation boundary for future special weapons.
# Ordinary bombs intentionally consume held/queued fire, as in putBomb.
func poll(id: int = 0, players: int = 1) -> PlayerCommands:
	var command := PlayerCommands.new()
	var prefix := "p%d_" % (id+1)
	var held: Array[bool] = []
	for direction_name in ["left","up","right","down"]:
		var pressed := _direction_pressed(prefix + direction_name)
		if players == 1:
			pressed = _direction_pressed("p2_" + direction_name) or pressed
		held.append(pressed)
	command.direction = PlayerCommands.priority_direction(held[0],held[1],held[2],held[3])
	command.bomb_requested = Input.is_action_pressed(prefix + "bomb")
	command.bomb_pressed = Input.is_action_just_pressed(prefix + "bomb")
	command.bomb_released = Input.is_action_just_released(prefix + "bomb")
	return command
