extends SceneTree

var failed := false
var trace_rows: Dictionary = {}

func _init() -> void:call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func arena() -> GameState:
	var state := GameState.new()
	var rows := PackedStringArray()
	for y in 13:rows.append("...............")
	state.setup(rows)
	for hero in state.heroes:
		hero.controller = HeroState.Controller.HUMAN
		hero.cell = Vector2i(hero.id,0)
		hero.shield = 1000
	state.heroes[0].cell = Vector2i(6,6)
	state.heroes[0].facing = 2
	return state

func run() -> void:
	# Expectations are source Sound.start observations in issue-10-capture.
	var expected := {"rocket-wall":["rocket","explode"],"rocket-brick":["rocket"],"mine":["mine","explode"],"grenade":["grenade","explode"],"gas":[],"ice":[],"fire-brick":["explode"],"fire":[]}
	for scenario in expected:
		var state := arena()
		var hero := state.heroes[0]
		hero.special_weapon = scenario.split("-")[0]
		hero.special_count = 1
		if scenario.ends_with("brick"):state.cell_at(Vector2i(7,6)).kind = GameState.Kind.BRICK
		if scenario.ends_with("wall"):state.cell_at(Vector2i(7,6)).kind = GameState.Kind.SOLID
		var observed: Array[String] = []
		for tick in 31:
			if scenario == "mine" and tick == 1:state.cell_at(Vector2i(6,6)).energy = 1
			var command := PlayerCommands.new()
			command.bomb_requested = tick == 0
			state.tick([command])
			observed.append_array(state.audio_cues)
		trace_rows[scenario] = observed
		check(observed == expected[scenario],scenario+" source cue order and multiplicity: "+str(observed))
	var state := arena()
	state.heroes[1].cell = Vector2i(9,6)
	var fire := PlayerCommands.new()
	fire.bomb_requested = true
	state.tick([fire,fire])
	check(state.audio_cues == ["place","place"],"simultaneous placements each start a cue")
	for bomb in state.bombs:bomb.fuse = 1
	state.tick([])
	check(state.audio_cues == ["explode","explode"],"simultaneous explosions preserve both source starts")
	state = arena()
	state.heroes[0].cell = Vector2i(7,6)
	state.tick([fire])
	state.heroes[0].cell = Vector2i(6,6)
	state.heroes[0].glove = true
	var move := PlayerCommands.new()
	move.direction = Vector2i.RIGHT
	state.tick([move])
	check(state.audio_cues == ["push"],"a successful glove push starts the recovered push cue")
	state = arena()
	state.cell_at(Vector2i(7,6)).item = "shield"
	var pickups: Array[String] = []
	for tick in 8:
		var commands: Array[PlayerCommands] = []
		if tick == 0:commands.append(move)
		state.tick(commands)
		pickups.append_array(state.audio_cues)
	check(pickups == ["pickup"],"collecting one normal pickup emits exactly one tool cue")
	print("AUDIO_TRACE ",JSON.stringify(trace_rows))
	if not failed:print("AUDIO_OK")
	quit(1 if failed else 0)

