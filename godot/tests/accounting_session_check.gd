extends SceneTree
## Public session transitions; source frame 2 resets round bomb allowance to one.
var failed := false

func _init() -> void:
	var game := GameSession.new()
	game.start(32,1,1,2)
	for i in [2,3]:
		game.state.heroes[i].moving = true
		game.state.heroes[i].ticks_remaining = 9999
		game.state.heroes[i].step_duration = 9999
		game.state.heroes[i].direction = Vector2i.ZERO
	var owner := game.state.heroes[0]
	var fire := PlayerCommands.new()
	fire.bomb_requested = true
	game.tick([fire])
	check(game.state.bombs.size() == 1 and owner.bombs_available == 0,"Placement spends the live owner's allowance")
	game.state.bombs[0].fuse = 3
	# Damage away from the bomb: otherwise energy chains it while owner is alive.
	owner.cell += Vector2i.RIGHT
	owner.shield = 0
	var hit_cell := game.state.cell_at(owner.cell)
	hit_cell.energy = 1
	hit_cell.energy_owner = 2
	game.tick([])
	check(not owner.alive and owner.lives == 2 and game.result == "","Second human keeps round active after owner removal")
	game.tick([])
	game.tick([])
	check(game.state.bombs.is_empty() and owner.bombs_available == 0,"Expired bomb does not refund removed owner during live session")
	var survivor := game.state.heroes[1]
	survivor.shield = 0
	hit_cell = game.state.cell_at(survivor.cell)
	hit_cell.energy = 1
	hit_cell.energy_owner = 2
	game.tick([])
	check(game.result == "lose" and game.can_continue(),"Remaining lives permit retry after both humans are removed")
	var total := game.totals[2]
	game.next_round()
	check(game.stage == 1 and game.result == "" and game.totals[2] == total,"Retry preserves stage and accumulated score")
	for i in [0,1]:
		var actor := game.state.heroes[i]
		check(actor.alive and actor.lives == 2 and actor.bombs_available == 1 and actor.bomb_capacity == 1,"Retry recreates one bomb allowance while retaining lives")
	# Source round setup resets the allowance even after an upgraded prior round.
	game.state.heroes[0].bomb_capacity = 4
	game.state.heroes[0].bombs_available = 4
	game.state.heroes[2].alive = false
	game.state.heroes[3].alive = false
	game.tick([])
	check(game.result == "win","Survivors can progress after retry")
	game.next_round()
	check(game.stage == 2 and game.state.heroes[0].bomb_capacity == 1 and game.state.heroes[0].bombs_available == 1,"Progression also resets source round allowance")
	if failed:
		quit(1)
		return
	print("ACCOUNTING_SESSION_OK")
	quit()

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
