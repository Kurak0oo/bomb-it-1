extends SceneTree

var failed := false
var main: Node

func _init() -> void:
	call_deferred("run")

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(at: Vector2) -> void:
	for down in [true, false]:
		mouse(at, down)

func mouse(at: Vector2, down: bool, device: int = 0, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.device = device
	event.double_click = double_click
	root.push_input(event, true)

func move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	root.push_input(event, true)

func finger(at: Vector2, down: bool, id: int = 0, cancelled: bool = false, double_tap: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = id
	event.pressed = down
	event.canceled = cancelled
	event.double_tap = double_tap
	root.push_input(event, true)

func tap(at: Vector2) -> void:
	finger(at, true)
	finger(at, false)

func press(code: Key) -> void:
	key(code, true)
	key(code, false)

func capture(name_text: String) -> void:
	await preload("res://tests/qa_capture.gd").capture(self, "menu-" + name_text)

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func run() -> void:
	root.size = Vector2i(550,400)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	main.set_physics_process(false)
	root.add_child(main)
	await process_frame
	await capture("title")
	move(Vector2(477,100))
	await capture("title-hover")
	mouse(Vector2(477,100), true)
	await capture("title-pressed")
	mouse(Vector2(1,1), false)
	check(main.screen == "menu", "release outside cancels navigation")
	move(Vector2(1,1))
	# Original title's Start Game goes to a separate player-count screen.
	click(Vector2(477,100))
	check(main.screen == "players", "title Start Game must open original player-count screen")
	await capture("players")
	click(Vector2(470,233))
	check(main.screen == "difficulty" and main.players == 2, "original 2 PLAYERS button enters two-player difficulty choice")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	check(main.screen == "players", "selection Back returns to player-count choice")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	check(main.screen == "menu", "player-count Back returns to original title")
	# Input devices cannot take over another device's in-progress press.
	key(KEY_ENTER, true)
	mouse(Vector2(477,149), true)
	key(KEY_ENTER, false)
	check(main.screen == "players", "mouse press cannot replace keyboard's captured Start button")
	mouse(Vector2(477,149), false)
	check(main.screen == "players", "old mouse release cannot activate player choice")
	press(KEY_ESCAPE)
	finger(Vector2(477,149), true)
	press(KEY_ENTER)
	check(main.screen == "menu", "keyboard release cannot complete a touch press")
	finger(Vector2(477,149), false)
	check(main.screen == "help", "touch owner completes its own Help press")
	press(KEY_ESCAPE)
	click(Vector2(477,149))
	check(main.screen == "help", "title opens controls help")
	move(Vector2(1,1))
	await capture("controls")
	move(Vector2(132,334))
	await capture("controls-hover")
	mouse(Vector2(132,334), true)
	await capture("controls-pressed")
	mouse(Vector2(1,1), false)
	click(Vector2(132,334))
	check(main.screen == "powerups", "controls opens the original power-up guide")
	mouse(Vector2(132,334), true, 0, true)
	mouse(Vector2(132,334), false)
	check(main.screen == "powerups", "second click of a double-click cannot bounce back from guide")
	move(Vector2(1,1))
	await capture("powerups")
	move(Vector2(439,334))
	await capture("powerups-hover")
	mouse(Vector2(439,334), true)
	await capture("powerups-pressed")
	mouse(Vector2(1,1), false)
	move(Vector2(1,1))
	root.size = Vector2i(1600,800)
	await capture("powerups-landscape")
	# Input is in viewport coordinates, independent of the wider window.
	main.touch_enabled = true
	tap(main.position + Vector2(132,334))
	check(main.screen == "help", "wide landscape guide supports direct touch")
	await capture("controls-touch-landscape")
	root.size = Vector2i(550,400)
	await process_frame
	click(Vector2(132,334))
	click(Vector2(132,334))
	check(main.screen == "help", "power-up guide returns to controls")
	click(Vector2(439,334))
	check(main.screen == "players" and main.players == 2, "help Start preserves player count until a new choice")
	press(KEY_ESCAPE)
	# Keyboard activation is release-based, and echo cannot skip a screen.
	key(KEY_ENTER, true)
	key(KEY_ENTER, true, true)
	check(main.screen == "menu", "held Enter waits for release")
	key(KEY_ENTER, false)
	key(KEY_ENTER, true, true)
	key(KEY_ENTER, false)
	check(main.screen == "players", "repeat and orphan release do not activate a new screen")
	press(KEY_ESCAPE)
	press(KEY_DOWN)
	press(KEY_ENTER)
	check(main.screen == "help", "keyboard opens help")
	press(KEY_ENTER)
	check(main.screen == "powerups", "keyboard opens power-up guide")
	press(KEY_ENTER)
	check(main.screen == "help", "keyboard returns to controls")
	press(KEY_ENTER)
	press(KEY_RIGHT)
	press(KEY_ENTER)
	check(main.screen == "players", "keyboard guide Start opens player choice")
	press(KEY_ESCAPE)
	# Cancelled, unrelated and emulated pointer events cannot reuse a press.
	finger(Vector2(477,100), true, 7)
	finger(Vector2(477,100), false, 8)
	check(main.screen == "menu", "unrelated touch cannot release the captured finger")
	finger(Vector2(477,100), false, 7, true)
	finger(Vector2(477,100), false, 7)
	check(main.screen == "menu", "cancelled touch cannot navigate")
	finger(Vector2(477,100), true)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	finger(Vector2(477,100), false)
	check(main.screen == "menu", "focus loss cancels menu press")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	tap(Vector2(477,149))
	mouse(Vector2(132,334), true, InputEvent.DEVICE_ID_EMULATION)
	mouse(Vector2(132,334), false, InputEvent.DEVICE_ID_EMULATION)
	check(main.screen == "help", "emulated mouse cannot double-activate after touch navigation")
	tap(Vector2(132,334))
	check(main.screen == "powerups", "touch opens guide without hover")
	finger(Vector2(132,334), true, 0, false, true)
	finger(Vector2(132,334), false)
	check(main.screen == "powerups", "double tap cannot bounce back from guide")
	var was_muted: bool = main.audio.muted
	tap(Vector2(150,387))
	check(main.audio.muted != was_muted, "touch sound control works on guide")
	tap(Vector2(132,334))
	check(main.screen == "help" and main.players == 2 and main.audio.muted != was_muted, "guide return preserves players and sound")
	tap(Vector2(132,334))
	tap(Vector2(439,334))
	check(main.screen == "players", "touch guide Start opens player choice")
	tap(Vector2(470,155))
	check(main.screen == "difficulty" and main.players == 1, "touch selects one player")
	press(KEY_ESCAPE)
	tap(Vector2(485,383))
	check(main.screen == "menu", "touch Back returns to title")
	main.high_score = 123456
	click(Vector2(477,198))
	await capture("title-local-best-muted")
	check(main.screen == "menu" and main.high_score == 123456, "Highscores retains the saved local best")
	click(Vector2(477,247))
	check(main.screen == "menu", "unavailable portal stays on title")
	tap(Vector2(477,149))
	main.set_physics_process(true)
	await physics_frame
	await physics_frame
	check(main.session.state == null, "help never starts a simulation")
	main.set_physics_process(false)
	main.queue_free()
	await create_timer(1.0).timeout
	if not failed:
		print("MENU_RENDER_OK")
	quit(1 if failed else 0)
