extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("run")

func key(pressed: bool, code: Key = KEY_ENTER) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func finger(pressed: bool, cancelled: bool = false, id: int = 1, point: Vector2 = Vector2(495,325)) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	event.canceled = cancelled
	root.push_input(event, true)

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func run_ticks(main: Node, count: int) -> void:
	var end: int = main.session.state.tick_number + count
	main.set_physics_process(true)
	while main.session.state.tick_number < end:
		await physics_frame
		await process_frame
	main.set_physics_process(false)

func run() -> void:
	root.size = Vector2i(550,400)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	main.set_physics_process(false)
	root.add_child(main)
	key(true)
	key(false)
	key(true)
	key(false)
	await process_frame
	key(true)
	key(false)
	await process_frame
	key(true)
	key(false)
	await process_frame
	check(main.screen == "game", "keyboard menu navigation starts game")
	main.touch_enabled = true
	main.touch.visible = true
	await process_frame
	await RenderingServer.frame_post_draw
	var actor: HeroState = main.session.state.heroes[0]
	actor.special_weapon = "mine"
	actor.special_count = 5
	# Both platform events arrive before any simulation tick.
	finger(true)
	finger(false)
	await run_ticks(main, 2)
	check(actor.special_count == 4, "brief between-tick touch must fire exactly once")
	# Separate origins allow the visible shots to demonstrate release gating.
	actor.cell = Vector2i(4,3)
	finger(true)
	await run_ticks(main, 1)
	check(actor.special_count == 3, "next distinct press fires a second mine")
	actor.cell = Vector2i(5,3)
	finger(false)
	finger(true)
	await run_ticks(main, 3)
	check(actor.special_count == 2, "release and repress between ticks remain ordered")
	actor.cell = Vector2i(6,3)
	await run_ticks(main, 2)
	check(actor.special_count == 2, "holding special fire never repeats the shot")
	finger(false)
	await run_ticks(main, 1)
	finger(true)
	finger(true, true)
	check(not main.touch.bomb_held, "cancelled touch releases Bomb")
	await run_ticks(main, 2)
	check(actor.special_count == 2, "cancelled pending touch must not fire later")
	finger(true)
	main.touch.visible = false
	await run_ticks(main, 2)
	check(actor.special_count == 2, "hiding controls discards an unconsumed press")
	main.touch.visible = true
	key(true, KEY_SPACE)
	key(false, KEY_SPACE)
	await run_ticks(main, 2)
	check(actor.special_count == 1, "brief keyboard tap uses the same fire boundary")
	actor.cell = Vector2i(7,3)
	finger(true)
	key(true, KEY_P)
	key(false, KEY_P)
	check(main.paused, "pause delivered through actual keyboard input")
	key(true, KEY_P)
	key(false, KEY_P)
	await run_ticks(main, 2)
	check(actor.special_count == 1, "resume does not replay a pre-pause press")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(main.paused, "backgrounding pauses the active match")
	var stopped_at: int = main.session.state.tick_number
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	main.set_physics_process(true)
	await create_timer(0.1).timeout
	main.set_physics_process(false)
	check(main.paused and main.session.state.tick_number == stopped_at, "foregrounding waits for an intentional resume")
	finger(true)
	click(Vector2(260,250)) # MAIN MENU on the pause overlay.
	check(main.screen == "menu", "paused menu responds to pointer input")
	key(true)
	key(false)
	key(true)
	key(false)
	key(true)
	key(false)
	key(true)
	key(false)
	await process_frame
	check(main.screen == "game", "new match starts after an interruption")
	await run_ticks(main, 2)
	check(main.session.state.bombs.filter(func(bomb: BombState): return bomb.owner_id == 0).is_empty(), "scene changes and disabled controls cannot replay the human's fire")
	actor = main.session.state.heroes[0]
	actor.bomb_capacity = 3
	actor.bombs_available = 3
	for x in range(3,8):
		main.session.state.cell_at(Vector2i(x,3)).kind = GameState.Kind.FLOOR
	finger(true, false, 8, Vector2(182,325))
	finger(true)
	await run_ticks(main, 16)
	check(actor.cell.x > 3 and main.session.state.bombs.size() >= 2, "distinct fingers move and place ordinary held bombs together")
	finger(false, false, 9) # An unrelated finger cannot release the captured one.
	check(main.touch.bomb_held, "unrelated finger IDs do not release Bomb")
	finger(false)
	finger(false, false, 8, Vector2(182,325))
	await run_ticks(main, 7) # Finish the movement already accepted by the simulation.
	var resting_cell := actor.cell
	key(true, KEY_D)
	key(true, KEY_P)
	key(false, KEY_P)
	key(true, KEY_P)
	key(false, KEY_P)
	await run_ticks(main, 7)
	check(actor.cell == resting_cell and not actor.moving, "held pre-pause direction must wait for release and a fresh press")
	key(false, KEY_D)
	key(true, KEY_D)
	await run_ticks(main, 1)
	check(actor.moving, "fresh movement press after release resumes control")
	key(true, KEY_P)
	key(false, KEY_P)
	click(Vector2(260,250))
	key(true)
	key(false)
	key(true)
	key(false)
	key(true)
	key(false)
	key(true)
	key(false)
	await process_frame
	actor = main.session.state.heroes[0]
	var spawn := actor.cell
	await run_ticks(main, 7)
	check(actor.cell == spawn and not actor.moving, "held direction from the previous match cannot move a new hero")
	key(false, KEY_D)
	main.queue_free()
	await create_timer(1.0).timeout
	if not failed:
		print("INPUT_RENDER_OK")
	quit(1 if failed else 0)
