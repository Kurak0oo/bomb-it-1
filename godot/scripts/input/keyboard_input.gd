class_name KeyboardInput
extends RefCounted

# Edges are carried to the simulation boundary for future special weapons.
# Ordinary bombs intentionally consume held/queued fire, as in putBomb.
func poll(id: int = 0, players: int = 1) -> PlayerCommands:
	var command := PlayerCommands.new()
	var prefix := "p%d_" % (id+1)
	var held: Array[bool] = []
	for direction_name in ["left","up","right","down"]:
		var pressed := Input.is_action_pressed(prefix + direction_name)
		if players == 1:
			pressed = pressed or Input.is_action_pressed("p2_" + direction_name)
		held.append(pressed)
	command.direction = PlayerCommands.priority_direction(held[0],held[1],held[2],held[3])
	command.bomb_requested = Input.is_action_pressed(prefix + "bomb")
	command.bomb_pressed = Input.is_action_just_pressed(prefix + "bomb")
	command.bomb_released = Input.is_action_just_released(prefix + "bomb")
	return command
