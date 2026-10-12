extends SceneTree

var _failed := false
var _boards: Array = []


func _init() -> void:
	_run()
	if _failed:
		quit(1)
	else:
		print("SIM_OK")
		quit(0)


func _run() -> void:
	_expect_eq(SimRules.MOVE_PER_TICK, 5.0, "5 px per tick")
	_expect_eq(SimRules.TILE_SIZE, 30, "tile")
	_expect_eq(SimRules.FRAMES_PER_TILE, 6, "frames per tile")
	_expect_eq(SimRules.SIMULATION_FPS, 35.0, "simulation fps")

	_expect_eq(PlayerCommands.priority_direction(true, true, true, true), Vector2i.LEFT, "left beats the rest")
	_expect_eq(PlayerCommands.priority_direction(false, true, false, true), Vector2i.UP, "up beats down")
	_expect_eq(PlayerCommands.priority_direction(true, false, true, false), Vector2i.LEFT, "left beats right")
	_expect_eq(PlayerCommands.priority_direction(false, false, false, true), Vector2i.DOWN, "down alone")
	_expect_eq(PlayerCommands.priority_direction(false, false, false, false), Vector2i.ZERO, "no direction")

	var board := GameState.new()
	_boards.append(board)
	board.setup_default()
	_expect_eq(board.cells.size(), 13, "rows")
	_expect_eq(board.cells[0].size(), 15, "columns")
	_expect_eq(board.cell_at(Vector2i(3, 3)).kind, GameState.Kind.FLOOR, "spawn floor")
	_expect_eq(board.heroes[0].cell, Vector2i(3, 3), "spawn cell")
	_expect_eq(board.heroes[0].facing, SimRules.FACING_DOWN, "spawn faces down")
	for solid in [Vector2i(6, 5), Vector2i(7, 5), Vector2i(6, 6), Vector2i(7, 6)]:
		_expect_eq(board.cell_at(solid).kind, GameState.Kind.SOLID, "center solid %s" % solid)
	_expect_eq(board.cell_at(Vector2i(4, 4)).kind, GameState.Kind.BRICK, "sample brick")

	_test_step()
	_test_blocked()
	_test_bomb_and_walk()
	_test_fuse_and_plus()
	_test_brick_stops_ray()
	_test_solid_blocks_ray()
	_test_chain()
	_test_just_placed_waits()
	_test_linger()
	_test_shield()
	_test_halfway_cell()


func _test_step() -> void:
	var board := _board()
	_tick(board, _cmd(Vector2i.RIGHT))
	_expect(board.heroes[0].moving, "decision tick starts a step")
	_expect_eq(board.heroes[0].ticks_remaining, 6, "six motion ticks armed")
	_expect_eq(board.heroes[0].cell, Vector2i(3, 3), "decision tick stays on the cell")
	_expect_eq(board.heroes[0].pixel_position(), Vector2(90, 90), "decision tick does not slide")
	var offsets := [5, 10, 15, 20, 25]
	for offset in offsets:
		_tick(board, _cmd(Vector2i.ZERO))
		_expect_eq(board.heroes[0].cell, Vector2i(3, 3), "still on origin during offset %s" % offset)
		_expect_eq(board.heroes[0].pixel_position(), Vector2(90 + offset, 90), "offset %s" % offset)
	_tick(board, _cmd(Vector2i.ZERO))
	_expect_eq(board.heroes[0].cell, Vector2i(4, 3), "snap lands on the target")
	_expect(not board.heroes[0].moving, "snap ends the step")
	_expect_eq(board.heroes[0].pixel_position(), Vector2(120, 90), "snap is exactly one tile")

	board = _board()
	for _i in 6:
		_tick(board, _cmd(Vector2i.RIGHT))
	_tick(board, _cmd(Vector2i.RIGHT))
	_expect_eq(board.heroes[0].cell, Vector2i(4, 3), "held key snaps onto the next cell")
	_expect_eq(board.heroes[0].pixel_position(), Vector2(120, 90), "new step does not slide on the snap tick")
	_expect(board.heroes[0].moving and board.heroes[0].ticks_remaining == 6, "next step is armed but not advanced")


func _test_blocked() -> void:
	var board := _board()
	board.heroes[0].cell = Vector2i(4, 3)
	_tick(board, _cmd(Vector2i.DOWN))
	_expect(not board.heroes[0].moving, "brick blocks")
	_expect_eq(board.heroes[0].cell, Vector2i(4, 3), "brick does not move the hero")
	_expect_eq(board.heroes[0].facing, SimRules.direction_index(Vector2i.DOWN), "facing updates into a brick")

	board.heroes[0].cell = Vector2i(5, 5)
	_tick(board, _cmd(Vector2i.RIGHT))
	_expect(not board.heroes[0].moving, "solid blocks")
	_expect_eq(board.heroes[0].cell, Vector2i(5, 5), "solid does not move the hero")
	_expect_eq(board.heroes[0].facing, SimRules.direction_index(Vector2i.RIGHT), "facing updates into a solid")
	_expect_eq(board.cell_at(Vector2i(6, 5)).kind, GameState.Kind.SOLID, "solid cell unchanged")

	board.heroes[0].cell = Vector2i(0, 1)
	_tick(board, _cmd(Vector2i.LEFT))
	_expect(not board.heroes[0].moving, "map edge blocks")
	_expect_eq(board.heroes[0].cell, Vector2i(0, 1), "edge does not move the hero")
	_expect_eq(board.heroes[0].facing, SimRules.direction_index(Vector2i.LEFT), "facing updates off the board")


func _test_bomb_and_walk() -> void:
	var board := _board()
	_tick(board, _cmd(Vector2i.ZERO, true))
	_expect_eq(board.heroes[0].bombs_available, 0, "place spends the charge")
	_expect_eq(board.bombs.size(), 1, "one bomb")
	_expect_eq(board.bombs[0].cell, Vector2i(3, 3), "bomb on the hero cell")
	_expect_eq(board.bombs[0].fuse, 60, "fuse stays 60 on the place tick")
	_tick(board, _cmd(Vector2i.ZERO, true))
	_expect_eq(board.heroes[0].bombs_available, 0, "second place rejected")
	_expect_eq(board.bombs.size(), 1, "still one bomb")

	board = _board()
	_tick(board, _cmd(Vector2i.ZERO, true))
	_tick(board, _cmd(Vector2i.RIGHT))
	for _i in 5:
		_tick(board, _cmd(Vector2i.ZERO))
	_tick(board, _cmd(Vector2i.ZERO))
	_expect_eq(board.heroes[0].cell, Vector2i(4, 3), "hero walks off the bomb")
	_expect_eq(board.bombs[0].cell, Vector2i(3, 3), "bomb stays behind")
	_tick(board, _cmd(Vector2i.LEFT))
	_expect(not board.heroes[0].moving, "cannot re-enter the bomb cell")
	_expect_eq(board.heroes[0].cell, Vector2i(4, 3), "blocked cell stays")
	_expect_eq(board.heroes[0].facing, SimRules.direction_index(Vector2i.LEFT), "facing updates into the bomb")

	board = _board()
	_tick(board, _cmd(Vector2i.RIGHT))
	_tick(board, _cmd(Vector2i.ZERO, true))
	_expect_eq(board.bombs.size(), 0, "fire while moving does not place yet")
	_expect(board.heroes[0].prev_fire, "fire while moving is queued")
	for _i in 4:
		_tick(board, _cmd(Vector2i.ZERO))
	_tick(board, _cmd(Vector2i.ZERO))
	_expect_eq(board.heroes[0].cell, Vector2i(4, 3), "arrival cell")
	_expect_eq(board.bombs.size(), 1, "queued bomb places on arrival")
	_expect_eq(board.bombs[0].cell, Vector2i(4, 3), "bomb is on the cell just entered")
	_expect(not board.heroes[0].prev_fire, "queue is consumed")


func _test_fuse_and_plus() -> void:
	var board := _board()
	board.heroes[0].shield = 1000
	_tick(board, _cmd(Vector2i.ZERO, true))
	_expect_eq(board.bombs[0].fuse, 60, "place tick is not a fuse tick")
	for _i in 59:
		_tick(board, _cmd(Vector2i.ZERO))
	_expect_eq(board.bombs.size(), 1, "bomb still live after 59 fuse ticks")
	_expect_eq(board.bombs[0].fuse, 1, "fuse is 1")
	_expect_eq(board.heroes[0].bombs_available, 0, "charge still spent")
	_tick(board, _cmd(Vector2i.ZERO, true))
	_expect_eq(board.bombs.size(), 1, "60th fuse tick refunds before held fire replaces the bomb")
	_expect_eq(board.heroes[0].bombs_available, 0, "same-update replacement spends the returned charge once")
	_expect_eq(board.bombs[0].fuse, 60, "replacement waits until its first child callback")
	_expect(_energy(board, Vector2i(3, 3)) > 0, "center is lit on the explode tick")
	for neighbor in [Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(3, 4)]:
		_expect_eq(_energy(board, neighbor), 0, "neighbor dark on the explode tick %s" % neighbor)
	_tick(board, _idle())
	for neighbor in [Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(3, 4)]:
		_expect(_energy(board, neighbor) > 0, "neighbor lit one tick later %s" % neighbor)
	for far in [Vector2i(1, 3), Vector2i(5, 3), Vector2i(3, 1), Vector2i(3, 5)]:
		_expect_eq(_energy(board, far), 0, "range stops at one tile %s" % far)
	_tick(board, _cmd(Vector2i.ZERO, true))
	_expect_eq(board.bombs.size(), 1, "returned charge can be used on a later tick")


func _test_brick_stops_ray() -> void:
	var board := _board()
	# (1, 2) floor, brick at (4, 2). Level 3 would reach it and must stop there.
	_plant(board, Vector2i(1, 2), 1, false, 3)
	_tick(board, _idle())
	for _i in 3:
		_tick(board, _idle())
	_expect_eq(board.cell_at(Vector2i(4, 2)).kind, GameState.Kind.FLOOR, "brick in the ray is destroyed")
	_expect(_energy(board, Vector2i(4, 2)) > 0, "destroyed brick still receives the flame")
	_expect_eq(_energy(board, Vector2i(5, 2)), 0, "ray does not continue past the brick")
	_expect_eq(board.cell_at(Vector2i(5, 2)).kind, GameState.Kind.FLOOR, "cell past the brick was never a target")


func _test_solid_blocks_ray() -> void:
	var board := _board()
	_plant(board, Vector2i(5, 5), 1, false, 1)
	_tick(board, _idle())
	_tick(board, _idle())
	_expect_eq(_energy(board, Vector2i(6, 5)), 0, "unbreakable neighbor is never entered")
	_expect_eq(board.cell_at(Vector2i(6, 5)).kind, GameState.Kind.SOLID, "solid remains")
	_expect(_energy(board, Vector2i(5, 4)) > 0, "open neighbor is entered")
	_expect_eq(_energy(board, Vector2i(7, 5)), 0, "flame does not pass through the solid")


func _test_chain() -> void:
	var board := _board()
	_plant(board, Vector2i(3, 3), 1, false, 1)
	_plant(board, Vector2i(4, 3), 40, false, 1)
	_tick(board, _idle())
	_expect_eq(board.bombs.size(), 1, "neighbor bomb survives the center-only tick")
	_expect_eq(board.bombs[0].cell, Vector2i(4, 3), "survivor is the neighbor")
	_expect_eq(board.bombs[0].fuse, 39, "neighbor fuse ticks while the center is alone")
	_expect_eq(_energy(board, Vector2i(4, 3)), 0, "neighbor not painted yet")
	_tick(board, _idle())
	_expect_eq(board.bombs.size(), 0, "flame sets fuse to 0 and explodes the same tick")
	_expect(_energy(board, Vector2i(4, 3)) > 0, "chained bomb lights its own cell")


func _test_just_placed_waits() -> void:
	var board := _board()
	_plant(board, Vector2i(3, 3), 1, false, 1)
	_tick(board, _idle())
	board.heroes[0].cell = Vector2i(4, 3)
	board.heroes[0].bombs_available = 1
	_tick(board, _cmd(Vector2i.ZERO, true))
	_expect_eq(board.bombs.size(), 1, "bomb placed into a flame waits out its creation tick")
	_expect_eq(board.bombs[0].fuse, 60, "creation tick does not chain")
	_expect(_energy(board, Vector2i(4, 3)) > 0, "the cell is already burning")
	_tick(board, _idle())
	_expect_eq(board.bombs.size(), 0, "next tick the flame chains it")


func _test_linger() -> void:
	var board := _board()
	_plant(board, Vector2i(3, 3), 1, false, 1)
	_tick(board, _idle())
	_tick(board, _idle())
	_expect(_energy(board, Vector2i(3, 3)) > 0, "energy on at growth")
	for _i in 9:
		_tick(board, _idle())
		_expect(_energy(board, Vector2i(3, 3)) > 0, "energy remains through linger")
	_tick(board, _idle())
	_expect_eq(_energy(board, Vector2i(3, 3)), 0, "energy clears on the 10th tick after growth")
	_expect_eq(_energy(board, Vector2i(4, 3)), 0, "neighbor energy clears with the center")


func _test_shield() -> void:
	var board := _board()
	board.heroes[0].shield = 60
	board.cell_at(board.heroes[0].cell).energy = 1
	for _i in 60:
		_tick(board, _idle())
		_expect(board.heroes[0].alive, "shield tick still skips damage")
	_tick(board, _idle())
	_expect(not board.heroes[0].alive, "damage lands once the shield is spent")


func _test_halfway_cell() -> void:
	var board := _board()
	board.heroes[0].shield = 0
	_tick(board, _cmd(Vector2i.RIGHT))
	_tick(board, _idle())
	_tick(board, _idle())
	_tick(board, _idle())
	_expect_eq(board.heroes[0].pixel_position(), Vector2(105, 90), "halfway across the tile")
	_expect_eq(board.heroes[0].rounded_cell(), Vector2i(4, 3), "halfway rounds to the destination")
	board.cell_at(Vector2i(4, 3)).energy = 1
	_tick(board, _idle())
	_expect(not board.heroes[0].alive, "flame on the rounded cell hurts")


func _board() -> GameState:
	var board := GameState.new()
	_boards.append(board)
	board.setup_default()
	board.heroes[0].shield = 1000
	return board


func _plant(board: GameState, at: Vector2i, fuse: int, just_placed: bool, level: int) -> void:
	var bomb := BombState.new(at)
	bomb.fuse = fuse
	bomb.just_placed = just_placed
	bomb.level = level
	board.cell_at(at).bomb = bomb
	board.bombs.append(bomb)
	board.register_callback(bomb)


func _cmd(dir: Vector2i, bomb := false) -> PlayerCommands:
	var commands := PlayerCommands.new()
	if dir != Vector2i.ZERO:
		commands.request_direction(dir)
	if bomb:
		commands.request_bomb()
	return commands


func _idle() -> PlayerCommands:
	return PlayerCommands.new()


func _energy(board: GameState, at: Vector2i) -> int:
	return board.cell_at(at).energy


func _expect(cond: bool, msg: String) -> void:
	if cond:
		return
	_failed = true
	print("FAIL: " + msg)


func _expect_eq(actual, expected, msg: String) -> void:
	if actual == expected:
		return
	_failed = true
	print("FAIL: %s (got %s, expected %s)" % [msg, actual, expected])


func _tick(board: GameState, command: PlayerCommands) -> void:
	board.tick([command])
