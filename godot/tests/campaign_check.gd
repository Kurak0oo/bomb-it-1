extends SceneTree

var failed := false

func _init() -> void:
	for seed_value in range(1, 31):
		var state := GameState.new()
		state.setup_round(seed_value, seed_value % 4 + 1, 1, seed_value % 3)
		var other := GameState.new()
		other.setup_round(seed_value, seed_value % 4 + 1, 1, seed_value % 3)
		for y in SimRules.ROWS:
			for x in SimRules.COLUMNS:
				var at := Vector2i(x,y)
				check(state.cell_at(at).kind == other.cell_at(at).kind, "seeded map reproduction")
		for hero in state.heroes:
			check(state.cell_at(hero.cell).kind == GameState.Kind.FLOOR, "spawn clear")
			for i in 4:
				check(state.cell_at(hero.cell + SimRules.direction(i)).kind == GameState.Kind.FLOOR, "spawn exit clear")
		var seen := {}
		var queue: Array[Vector2i] = [state.heroes[0].cell]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			if seen.has(at):
				continue
			seen[at] = true
			for i in 4:
				var next := at + SimRules.direction(i)
				var cell := state.cell_at(next)
				if cell != null and cell.kind != GameState.Kind.SOLID:
					queue.append(next)
		for hero in state.heroes:
			check(seen.has(hero.cell), "solid layout connects all spawns")

	var game := GameSession.new()
	game.start(72, 1, 1, 1)
	var bomb_count := 0
	for i in 6300:
		game.tick([])
		bomb_count += game.state.events.count("place")
		if game.result != "":
			break
	check(bomb_count > 0, "AI actually plants bombs")
	check(game.result != "", "round always terminates")
	var tick := game.state.tick_number
	game.tick([])
	check(game.state.tick_number == tick, "finished rounds stop simulation")

	game.start(1, 0, 4, 2)
	game.state.heroes[2].alive = false
	game.state.heroes[3].alive = false
	game.tick([])
	check(game.result == "win" and game.totals[0] > 1000, "two-player win and time bonus")
	game.next_round()
	check(game.stage == 2 and game.result == "", "campaign advances")
	game.remaining_ticks = 1
	game.tick([])
	check(game.result == "timeup_lose", "time-up tie favors opponents")
	var previous := game.state
	game.next_round()
	for y in 13:
		for x in 15:
			var at := Vector2i(x,y)
			check((game.state.cell_at(at).kind == GameState.Kind.SOLID) == (previous.cell_at(at).kind == GameState.Kind.SOLID), "retry preserves solid layout")

	var state := GameState.new()
	state.setup_default()
	var hero := state.heroes[0]
	for item in ["life", "glove", "bomb", "shield", "power", "shoe"]:
		state.cell_at(hero.cell).item = item
		state._collect_item(hero)
		check(state.cell_at(hero.cell).item == "", "normal pickup consumed")
	check(hero.lives == 2 and hero.glove and hero.armor, "life glove and armor effects")
	check(hero.bombs_available == 2 and hero.bomb_level == 2 and hero.speed_level == 5, "bomb range and speed effects")
	hero.shield = 0
	state.cell_at(hero.cell).energy = 1
	state.tick([])
	check(hero.alive and not hero.armor and hero.shield == 60, "shield absorbs hit")
	state.cell_at(hero.cell).energy = 0
	for i in 20:
		state.cell_at(hero.cell).item = "shoe"
		state._collect_item(hero)
	check(hero.speed_level == 3, "shoe caps at three ticks per tile")
	if not failed:
		print("CAMPAIGN_OK")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		print("FAIL: " + message)
