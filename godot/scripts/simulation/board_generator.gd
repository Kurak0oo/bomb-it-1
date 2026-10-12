class_name BoardGenerator
extends RefCounted

const AROUND: Array[Vector2i] = [Vector2i(-1,0), Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1)]
const BRICKS = [[1,2,3,4,5,6], [10,11,12], [20,21,22,23], [32,33,34,35,36,37,38], [42,43,44,45,46,47]]
const SOLIDS = [[7,8,9], [13,14,15,16,17,18,19], [24,25,26,27,28,29,30,31], [39,40,41], [48,49,50,51]]

# Direct port of Sprite 564 frame 1 ranMap, then frame 2 brick population.
static func generate(state: GameState, rng: OriginalRng) -> void:
	state.scene_style = rng.next(5)
	var bricks: Array = BRICKS[state.scene_style].duplicate()
	var solids: Array = SOLIDS[state.scene_style].duplicate()
	rng.disorder(bricks)
	rng.disorder(solids)
	state.brick_styles = bricks
	state.floor_style = [1,4,6,8,11][state.scene_style] + rng.next([3,2,2,3,2][state.scene_style])
	state.center_style = [52,53,55,57,58][state.scene_style]
	if state.scene_style == 1 or state.scene_style == 2:
		state.center_style += rng.next(2)
	for y in range(5, 7):
		for x in range(6, 8):
			state.cell_at(Vector2i(x,y)).kind = GameState.Kind.SOLID
	var candidates: Array[Vector2i] = []
	for y in SimRules.ROWS:
		for x in SimRules.COLUMNS:
			var at := Vector2i(x,y)
			var safe := false
			for spawn in SimRules.SPAWNS:
				var distance: Vector2i = at - spawn
				if absi(distance.x) + absi(distance.y) <= 1:
					safe = true
			if not safe:
				candidates.append(at)
	var original_length := candidates.size()
	for i in original_length:
		var j := rng.next(original_length)
		var temporary := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temporary
	for spawn in SimRules.SPAWNS:
		for j in [1,3,5,7]:
			candidates.push_front(spawn + AROUND[j])
	# Preserve original ranMapL: the sixteen inserted entries do not extend loop.
	for i in original_length:
		var at := candidates[i]
		if blocked(state, at):
			continue
		var enclosed := false
		for j in [0,2,4,6]:
			if blocked(state, at + AROUND[j]) and blocked(state, at + AROUND[(j+1)%8]) and blocked(state, at + AROUND[(j+2)%8]):
				enclosed = true
		if enclosed:
			continue
		var empty := not blocked(state, at + Vector2i.LEFT)
		var total_empty := 1 if empty else 0
		var total_brick := 0 if empty else 1
		var j := 1
		while j < 8:
			if empty:
				if blocked(state, at + AROUND[j]):
					empty = false
					total_brick += 1
			elif not blocked(state, at + AROUND[j]):
				if j % 2 == 0 or not blocked(state, at + AROUND[(j+1)%8]):
					empty = true
					total_empty += 1
				else:
					j += 2
			j += 1
		if total_empty + total_brick <= 3:
			var cell := state.cell_at(at)
			cell.kind = GameState.Kind.SOLID
			cell.style = solids[rng.next(2)]
	populate(state, rng)

static func populate(state: GameState, rng: OriginalRng) -> void:
	for y in SimRules.ROWS:
		for x in SimRules.COLUMNS:
			var cell := state.cell_at(Vector2i(x,y))
			if cell.kind != GameState.Kind.SOLID:
				cell.kind = GameState.Kind.FLOOR
			if cell.kind != GameState.Kind.SOLID and rng.next(100) < 60:
				cell.kind = GameState.Kind.BRICK
				cell.style = state.brick_styles[rng.next(mini(4, state.brick_styles.size()))]
	for hero in state.heroes:
		hero.shield = 60 + rng.next(4)
		state.cell_at(hero.cell).kind = GameState.Kind.FLOOR
		for i in 4:
			state.cell_at(hero.cell + SimRules.direction(i)).kind = GameState.Kind.FLOOR

static func blocked(state: GameState, at: Vector2i) -> bool:
	var cell := state.cell_at(at)
	# AS2 undefined.brick != "" evaluates true at map edges.
	return cell == null or cell.kind != GameState.Kind.FLOOR
