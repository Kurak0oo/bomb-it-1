class_name AiController
extends RefCounted

static func is_safe(state: GameState, at: Vector2i) -> bool:
	var cell := state.cell_at(at)
	if cell == null or cell.kind != GameState.Kind.FLOOR or cell.bomb != null or cell.energy > 0:
		return false
	for blast in state.explosions:
		if blast.origin == at:
			return false
	for i in 4:
		var distance := 1
		var target := at + SimRules.direction(i)
		while not BoardGenerator.blocked(state, target):
			var next_cell := state.cell_at(target)
			if next_cell.bomb != null and next_cell.bomb.level >= distance:
				return false
			for blast in state.explosions:
				if blast.origin == target and blast.level >= distance:
					return false
			target += SimRules.direction(i)
			distance += 1
	return true

static func score(state: GameState, at: Vector2i) -> int:
	if not is_safe(state, at):
		return -1
	var result := 0
	for i in 4:
		if is_safe(state, at + SimRules.direction(i)):
			result += 1
	return result

static func command(state: GameState, hero: HeroState) -> PlayerCommands:
	var result := PlayerCommands.new()
	if not hero.alive or hero.moving:
		return result
	var mode := 0
	if is_safe(state, hero.cell):
		if state.rng.next(100) < 20:
			mode = 1
		elif state.rng.next(100) < 5:
			mode = 2
	elif state.rng.next(100) < [20,60,100][state.difficulty]:
		mode = 3
	if mode == 0:
		return result
	var best := 0
	var chosen := -1
	var start := state.rng.next(4)
	for i in 4:
		var direction := (start + i) % 4
		var at := hero.cell + SimRules.direction(direction)
		var value := score(state, at)
		if mode == 3:
			if value >= best:
				best = value
				chosen = direction
		elif value > 0:
			if mode == 1:
				if state.cell_at(at).item != "":
					value += 5
				value += state.rng.next(3)
			if value >= best:
				best = value
				chosen = direction
	if mode == 3 and chosen < 0:
		chosen = state.rng.next(4)
	if chosen >= 0 and (mode != 2 or best >= 2):
		result.direction = SimRules.direction(chosen)
		result.bomb_requested = mode == 2
	return result
