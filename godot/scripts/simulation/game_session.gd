class_name GameSession
extends RefCounted

var state: GameState
var difficulty := 1
var humans := 1
var character := 1
var character2 := 2
var weapon_rotation: Array = []
var stage := 1
var total_stages := 20
var remaining_ticks := 180 * 35
var result := ""
var totals: Array[int] = [0,0,0,0]
var lives: Array[int] = [3,1,1,1]
var run_seed := 1

func start(seed_value: int, level: int, selected: int, players: int, second: int = 0) -> void:
	run_seed = seed_value
	difficulty = level
	character = selected
	character2 = second
	humans = players
	total_stages = [15,20,25][level]
	stage = 1
	totals = [0,0,0,0]
	lives = [3,3 if players == 2 else 1,1,1]
	_new_round()

func _new_round(retry: bool = false) -> void:
	var previous := state
	state = GameState.new()
	state.setup_round(run_seed, character, humans, difficulty, character2)
	if retry and previous != null:
		state.rng = previous.rng
		state.scene_style = previous.scene_style
		state.floor_style = previous.floor_style
		state.center_style = previous.center_style
		state.brick_styles = previous.brick_styles
		for y in SimRules.ROWS:
			for x in SimRules.COLUMNS:
				var at := Vector2i(x,y)
				var old := previous.cell_at(at)
				var cell := state.cell_at(at)
				cell.kind = GameState.Kind.SOLID if old.kind == GameState.Kind.SOLID else GameState.Kind.FLOOR
				cell.style = old.style
		BoardGenerator.populate(state, state.rng)
	if (stage % 3 == 1 and not retry) or weapon_rotation.is_empty():
		weapon_rotation = state.special_choices.duplicate()
	var offset := ((stage - 1) % 3) * 2
	state.special_choices = [weapon_rotation[offset], weapon_rotation[offset + 1]]
	run_seed += 1
	for id in 4:
		state.heroes[id].lives = lives[id]
	remaining_ticks = 180 * 35
	result = ""

func tick(human_commands: Array[PlayerCommands]) -> void:
	if result != "":
		return
	var commands: Array[PlayerCommands] = []
	for id in 4:
		if id < humans:
			commands.append(human_commands[id] if id < human_commands.size() else PlayerCommands.new())
		else:
			commands.append(AiController.command(state, state.heroes[id]))
	state.tick(commands)
	remaining_ticks -= 1
	var human_alive := false
	var ai_alive := false
	for hero in state.heroes:
		if hero.alive:
			if hero.id < humans:
				human_alive = true
			else:
				ai_alive = true
	if not human_alive:
		_finish("lose")
	elif not ai_alive:
		_finish("win")
	elif remaining_ticks <= 0:
		var human_score := 0
		var ai_score := 0
		for hero in state.heroes:
			if hero.alive:
				if hero.id < humans:
					human_score = maxi(human_score, hero.score)
				else:
					ai_score = maxi(ai_score, hero.score)
		_finish("timeup_win" if human_score > ai_score else "timeup_lose")

func _finish(outcome: String) -> void:
	result = outcome
	for hero in state.heroes:
		if hero.id < humans and hero.alive:
			if outcome.ends_with("win"):
				hero.bonus_score = 1000
				hero.time_score = int(remaining_ticks / 35.0 * 10) if outcome == "win" else 0
				hero.score += hero.bonus_score + hero.time_score
			elif outcome == "timeup_lose":
				hero.lives -= 1
		lives[hero.id] = hero.lives
		totals[hero.id] += hero.score

func can_continue() -> bool:
	for id in humans:
		if lives[id] > 0:
			return not (stage == total_stages and result.ends_with("win"))
	return false

func next_round() -> void:
	if result == "" or not can_continue():
		return
	var retry := not result.ends_with("win")
	if result.ends_with("win"):
		stage += 1
	for id in 4:
		if lives[id] <= 0:
			lives[id] = 1
			totals[id] = maxi(0, totals[id] - 1000)
	_new_round(retry)
