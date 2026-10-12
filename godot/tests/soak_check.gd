extends SceneTree

func _init() -> void:
	var total_ticks := 0
	var planted := 0
	var fired := 0
	var start := Time.get_ticks_usec()
	for seed_value in 18:
		var state := GameState.new()
		state.setup_round(seed_value + 100, seed_value % 4 + 1, 1, seed_value % 3)
		for hero in state.heroes:
			hero.controller = HeroState.Controller.AI
			# Force each special into long, mixed interactions, including flames.
			hero.special_weapon = SpecialRules.WEAPONS[(seed_value + hero.id) % 6]
			hero.special_count = 2
		for tick in 1200:
			var commands: Array[PlayerCommands] = []
			for hero in state.heroes:
				commands.append(AiController.command(state, hero))
			state.tick(commands)
			planted += state.events.count("place")
			for kind in SpecialRules.WEAPONS:
				fired += state.events.count(kind)
			for hero in state.heroes:
				if hero.bombs_available < 0 or hero.bombs_available > hero.bomb_capacity:
					push_error("Inventory invariant failed at seed %d tick %d" % [seed_value,tick])
					quit(1)
					return
			for row in state.cells:
				for cell in row:
					if cell.energy < 0:
						push_error("Negative energy at seed %d tick %d" % [seed_value,tick])
						quit(1)
						return
			total_ticks += 1
	if planted == 0 or fired == 0:
		push_error("Soak did not exercise bombs and specials: bombs=%d specials=%d" % [planted, fired])
		quit(1)
		return
	print("SOAK_OK ticks=%d bombs=%d specials=%d seconds=%.3f" % [total_ticks,planted,fired,(Time.get_ticks_usec()-start)/1000000.0])
	quit(0)
