extends SceneTree

var failed := false


func _init() -> void:
	var state := GameState.new()
	state.setup_default()
	check(state is RefCounted, "simulation needs no scene nodes")
	check(state.heroes.size() == 4, "four independent heroes")
	check(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") == 35, "engine clock is 35 Hz")
	var commands: Array[PlayerCommands] = []
	for id in 4:
		var hero := state.heroes[id]
		check(hero.id == id and hero.character_id == id + 1, "stable actor identity")
		check(hero.cell == SimRules.SPAWNS[id], "character spawn")
		hero.shield = 1000
		var command := PlayerCommands.new()
		command.request_bomb()
		commands.append(command)
	state.tick(commands)
	check(state.bombs.size() == 4, "each hero can place independently")
	for id in 4:
		check(state.bombs[id].owner_id == id, "bomb records its owner")
		check(state.heroes[id].bombs_available == 0, "placement spends only owner inventory")
	state.heroes[2].alive = false
	state.bombs[2].fuse = 1
	state.tick([])
	for id in 4:
		check(state.heroes[id].bombs_available == (1 if id == 2 else 0), "refund goes to owner even after death")
	state.tick(commands)
	check(state.bombs.size() == 3, "dead actor cannot place")

	# Held ordinary fire retries after the inventory returns, without a new edge.
	state = GameState.new()
	state.setup_default()
	state.heroes[0].shield = 1000
	state.tick([commands[0]])
	state.bombs[0].fuse = 1
	state.tick([commands[0]])
	state.tick([commands[0]])
	check(state.bombs.size() == 1, "held ordinary fire places again after refund")

	# Two owners chain; neither can receive the other's inventory.
	state = GameState.new()
	state.setup_default()
	state.heroes[1].cell = Vector2i(4, 3)
	state.tick([commands[0], commands[1]])
	state.bombs[0].fuse = 1
	state.tick([])
	state.tick([])
	check(state.bombs.is_empty(), "different owners chain")
	check(state.heroes[0].bombs_available == 1 and state.heroes[1].bombs_available == 1, "chain refunds each owner once")
	check(state.cell_at(Vector2i(4, 3)).energy == 2, "overlapping explosions count independently")
	for i in 16:
		state.tick([])
	check(state.cell_at(Vector2i(4, 3)).energy == 0, "overlap cleanup balances energy")

	state = GameState.new()
	state.setup_default()
	var right := PlayerCommands.new()
	right.direction = Vector2i.RIGHT
	var down := PlayerCommands.new()
	down.direction = Vector2i.DOWN
	state.tick([right, down])
	for i in 6:
		state.tick([])
	check(state.heroes[0].cell == Vector2i(4, 3), "hero zero moves independently")
	check(state.heroes[1].cell == Vector2i(11, 4), "hero one moves independently")
	check(state.heroes[2].cell == SimRules.SPAWNS[2], "missing command is idle")
	state.heroes[1].shield = 0
	state.cell_at(state.heroes[1].cell).energy = 1
	state.tick([])
	check(not state.heroes[1].alive and state.heroes[0].alive, "damage targets the actor on the lit cell")
	if not failed:
		print("ACTORS_OK")
	quit(1 if failed else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		print("FAIL: " + message)
