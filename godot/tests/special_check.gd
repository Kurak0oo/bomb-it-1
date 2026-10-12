extends SceneTree

var failed := false

func _init() -> void:
	var state := fresh()
	var hero := state.heroes[0]
	hero.special_weapon = "grenade"
	hero.special_count = 2
	hero.facing = 2
	var held := PlayerCommands.new()
	held.bomb_requested = true
	state.tick([held])
	check(state.specials.size() == 1 and hero.special_count == 1, "grenade consumes charge")
	for i in 17:
		state.tick([held])
	check(state.cell_at(Vector2i(5,3)).energy == 0, "grenade remains airborne before frame 19")
	state.tick([held])
	check(state.cell_at(Vector2i(5,3)).energy == 1, "grenade detonates at two-cell target")
	check(state.cell_at(Vector2i(6,3)).energy == 1, "grenade covers target neighbors")
	check(hero.special_count == 1, "holding special fire cannot repeat")
	var release := PlayerCommands.new()
	release.bomb_released = true
	state.tick([release])
	state.tick([held])
	check(hero.special_count == 0, "release rearms special fire")

	state = fresh()
	hero = state.heroes[0]
	hero.special_weapon = "mine"
	hero.special_count = 2
	state.tick([held])
	state.tick([])
	check(state.specials.size() == 1, "mine ignores owner")
	state.heroes[1].cell = hero.cell
	state.tick([])
	check(state.cell_at(hero.cell).energy == 1, "mine triggers on opponent")

	state = fresh()
	hero = state.heroes[0]
	hero.special_weapon = "gas"
	hero.special_count = 2
	state.tick([held])
	state.heroes[1].cell = hero.cell
	state.tick([])
	check(state.heroes[1].slow_ticks == 599, "gas sets 600 before the same parent tick decrements it")

	for kind in ["ice", "fire"]:
		state = fresh()
		hero = state.heroes[0]
		hero.special_weapon = kind
		hero.special_count = 2
		hero.facing = 2
		state.tick([held])
		for i in 12:
			state.tick([])
		check(state.specials[0].painted.size() == 3, "arrow grows three cells")
		check(state.cell_at(Vector2i(4,3)).kind == GameState.Kind.BRICK if kind == "ice" else state.cell_at(Vector2i(4,3)).energy == 1, "arrow affects target cells")
		for i in 37:
			state.tick([])
		check(state.specials.is_empty(), "arrow expires after counter 48")
		check(state.cell_at(Vector2i(4,3)).kind == GameState.Kind.FLOOR and state.cell_at(Vector2i(4,3)).energy == 0, "arrow cleanup restores cells")

	state = fresh()
	hero = state.heroes[0]
	hero.special_weapon = "rocket"
	hero.special_count = 2
	hero.facing = 2
	state.cell_at(Vector2i(5,3)).kind = GameState.Kind.BRICK
	state.tick([held])
	for i in 12:
		state.tick([])
	check(state.cell_at(Vector2i(5,3)).kind == GameState.Kind.FLOOR, "accelerating rocket breaks impact brick")
	check(state.cell_at(Vector2i(5,3)).energy > 0, "rocket impact is lethal")
	if not failed:
		print("SPECIAL_OK")
	quit(1 if failed else 0)

func fresh() -> GameState:
	var state := GameState.new()
	var rows := PackedStringArray()
	for i in 13:
		rows.append("...............")
	state.setup(rows)
	for hero in state.heroes:
		hero.shield = 1000
	return state

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		print("FAIL: " + message)
