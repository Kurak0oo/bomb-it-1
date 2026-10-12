extends SceneTree

var failed := false
var main: Node

func _init() -> void:
	call_deferred("run")

func click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = main.position + point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func key(code: Key, down: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(code: Key) -> void:
	key(code, true)
	key(code, false)

func capture(name_text: String) -> void:
	if main.screen == "select":
		main.original_menu.set_process(false)
	await preload("res://tests/qa_capture.gd").capture(self,name_text)

func touch(point: Vector2, down: bool, cancelled: bool = false, double_tap: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = main.position + point
	event.pressed = down
	event.index = 7
	event.canceled = cancelled
	event.double_tap = double_tap
	root.push_input(event,true)

func tap(point: Vector2) -> void:
	touch(point,true)
	touch(point,false)

func run() -> void:
	root.size = Vector2i(550,400)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	main.set_physics_process(false)
	root.add_child(main)
	await process_frame
	click(Vector2(477,100))
	click(Vector2(470,155))
	check(main.screen == "difficulty", "player count enters original difficulty screen before character selection")
	await capture("difficulty")
	press(KEY_ESCAPE)
	click(Vector2(470,233))
	click(Vector2(477,135))
	check(main.screen == "select" and main.difficulty == 0, "Easy enters two-player character selection")
	await capture("selection-2p")
	press(KEY_D)
	check(main.selected_character == 3 and main.selected_second_character == 2, "P1 skips robot already held by P2")
	await capture("selection-2p-changed")
	key(KEY_SPACE,true)
	key(KEY_SPACE,true,true)
	check(main.screen == "select", "held and echoed confirmation waits for release")
	key(KEY_SPACE,false)
	key(KEY_SPACE,false)
	press(KEY_D)
	check(main.screen == "select" and main.selected_character == 3, "confirmed P1 cannot move and waits for P2")
	await capture("selection-2p-confirmed")
	press(KEY_RIGHT)
	press(KEY_ENTER)
	check(main.screen == "game", "independent second confirmation starts existing GameSession")
	if main.screen == "game":
		check(main.session.state.heroes[0].character_id == 3 and main.session.state.heroes[1].character_id == 4, "GameSession receives both selected characters")
		check(main.session.state.heroes[0].lives == 3 and main.session.state.heroes[1].lives == 3, "both human players retain source starting lives")
	# Return through the rendered pause menu, then keyboard-select Easy from Normal.
	press(KEY_ESCAPE)
	click(Vector2(300,252))
	press(KEY_ENTER)
	press(KEY_ENTER)
	press(KEY_UP)
	press(KEY_ENTER)
	check(main.screen == "select" and main.difficulty == 0, "difficulty keyboard order follows Easy, Normal, Hard vertically")
	if main.screen == "select":
		check(main.selected_character == 1, "new player-count selection resets to source first character")
		await capture("selection-1p")
		var still: PackedByteArray = root.get_texture().get_image().get_data()
		main.original_menu.set_process(true)
		await create_timer(0.12).timeout
		main.original_menu.set_process(false)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().get_data() != still, "selected pointer and eyes animate without gameplay input")
		# Re-enter a fresh timeline for deterministic regression screenshots.
		press(KEY_ESCAPE)
		click(Vector2(477,135))
		press(KEY_RIGHT)
		await capture("selection-1p-changed")
		press(KEY_ESCAPE)
		check(main.screen == "difficulty", "selection Back returns to difficulty")
		click(Vector2(477,205))
		check(main.difficulty == 1 and main.selected_character == 2, "Normal forward navigation retains chosen character")
		press(KEY_ESCAPE)
		click(Vector2(477,275))
		check(main.difficulty == 2, "Hard is available")
		# Direct touch chooses an unselected robot; a cancelled confirmation stays.
		tap(Vector2(410,180))
		check(main.selected_character == 4, "touch selects a robot without hover")
		touch(Vector2(330,333),true)
		touch(Vector2(330,333),false,true)
		check(main.screen == "select", "cancelled touch cannot start a game")
		tap(Vector2(330,333))
		check(main.screen == "game" and main.session.difficulty == 2, "touch confirmation starts selected Hard session")
		if main.screen == "game":
			var state = main.session.state
			key(KEY_SPACE,false)
			check(main.session.state == state and state.heroes[0].character_id == 4, "orphan confirmation cannot restart session")
			press(KEY_ESCAPE)
			click(Vector2(300,252))
			tap(Vector2(477,100))
			tap(Vector2(470,233))
			tap(Vector2(477,205))
			tap(Vector2(229,180))
			check(main.selected_character == 1, "pointer cannot choose the other human's robot")
			tap(Vector2(320,180))
			tap(Vector2(263,340))
			touch(Vector2(263,340),true,false,true)
			touch(Vector2(263,340),false)
			check(main.screen == "select", "repeated first-player touch confirmation does not start 2P")
			tap(Vector2(320,180))
			check(main.selected_second_character == 2, "P2 cannot choose locked P1 robot")
			tap(Vector2(411,180))
			tap(Vector2(419,339))
			check(main.screen == "game" and main.session.humans == 2 and main.session.character == 3 and main.session.character2 == 4, "direct-touch 2P selection preserves both human choices")
	main.queue_free()
	await create_timer(1.0).timeout
	if not failed:
		print("SELECTION_RENDER_OK")
	quit(1 if failed else 0)
