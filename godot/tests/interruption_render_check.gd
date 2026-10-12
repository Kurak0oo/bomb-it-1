extends SceneTree

var failed := false
var main: Node2D
var tick_observations: Array = []

func _init() -> void:call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func key(pressed: bool, code: Key = KEY_ENTER) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = main.get_global_transform_with_canvas() * point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)

func finger(id: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = main.touch.get_global_transform_with_canvas() * point
	event.pressed = pressed
	root.push_input(event,true)

func ticks(count: int) -> void:
	var start_tick: int = main.session.state.tick_number
	var start_remaining: int = main.session.remaining_ticks
	var target: int = main.session.state.tick_number + count
	main.set_physics_process(true)
	while main.session.state.tick_number < target:
		await physics_frame
	# physics_frame precedes Node physics callbacks. Stop here before another
	# callback, including catch-up callbacks sharing the same display frame.
	main.set_physics_process(false)
	tick_observations.append({"requested":count,"accepted":main.session.state.tick_number-start_tick,"timer_ticks":start_remaining-main.session.remaining_ticks})
	check(main.session.state.tick_number == target,"render scheduling cannot make the fixture accept extra physics ticks")
	await process_frame

func run() -> void:
	root.size = Vector2i(550,400)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_physics_process(false)
	for i in 4:
		key(true)
		key(false)
		await process_frame
	check(main.screen == "game", "public menu input starts the match")
	key(true,KEY_SPACE)
	await ticks(1)
	check(main.session.state.bombs.size() > 0,"fixture places a bomb through keyboard input")
	var live_voice: AudioStreamPlayer
	for voice in main.audio.voices:
		if voice.playing:live_voice = voice
	check(live_voice != null,"placing a bomb starts an actual effect stream")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.paused,"focus loss pauses the active match")
	check(main.audio.music.stream_paused,"focus loss suspends music")
	check(live_voice != null and live_voice.stream_paused,"focus loss suspends active effect streams")
	var tick: int = main.session.state.tick_number
	main.set_physics_process(true)
	await create_timer(0.2).timeout
	main.set_physics_process(false)
	check(main.session.state.tick_number == tick,"unfocused wall time never advances simulation")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(main.paused,"focus return requires deliberate resume")
	click(Vector2(280,205))
	check(not main.paused,"visible Resume resumes the match")
	check(not main.audio.music.stream_paused and not live_voice.stream_paused,"deliberate resume restores suspended streams")
	key(false,KEY_SPACE)
	# Focus and background notifications can overlap and arrive separately.
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	click(Vector2(280,205))
	check(main.paused and main.audio.music.stream_paused,"focus return cannot resume a still-backgrounded app")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(main.paused,"foreground notification does not dismiss the pause")
	click(Vector2(280,205))
	check(not main.paused,"Resume works after both interruption reasons clear")
	# Pause between movement updates, then observe rendered positions without
	# accepting another simulation update. Resume must not rewind interpolation.
	for x in range(3,7):main.session.state.cell_at(Vector2i(x,3)).kind = GameState.Kind.FLOOR
	key(true,KEY_D)
	await ticks(2)
	var hero: HeroView
	for child in main.view.get_children():
		if child is HeroView and child.actor.id == 0:hero = child
	check(hero.actor.moving,"movement fixture is between tile endpoints")
	check(not hero.previous.is_equal_approx(hero.current),"movement fixture contains an interpolated displacement")
	key(true,KEY_P)
	key(false,KEY_P)
	await process_frame
	await RenderingServer.frame_post_draw
	var frozen_position: Vector2 = hero.position
	click(Vector2(280,205))
	for i in 6:
		await process_frame
		await RenderingServer.frame_post_draw
		check(hero.position.is_equal_approx(frozen_position),"resume never rewinds the rendered hero before the next accepted tick")
	key(false,KEY_D)
	key(true,KEY_P)
	key(false,KEY_P)
	click(Vector2(280,250))
	check(main.screen == "menu","pause menu returns to the idle menu")
	key(true) # Pending menu activation must be cancelled by the interruption.
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.audio.music.stream_paused,"idle menu audio suspends on focus loss")
	key(false)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(main.screen == "menu" and not main.paused,"idle menu returns usable without an extra Resume step")
	check(not main.audio.music.stream_paused,"idle menu audio returns after focus")
	for i in 4:
		key(true)
		key(false)
		await process_frame
	check(main.screen == "game","fresh menu presses still start a match")
	for id in [1,2,3]:main.session.state.heroes[id].alive = false
	await ticks(1)
	check(main.screen == "result","fixture reaches outcome through the live application")
	await create_timer(2.0).timeout
	key(true,KEY_SPACE)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var elapsed: float = main.original_results.elapsed
	main.set_physics_process(true)
	await create_timer(0.25).timeout
	main.set_physics_process(false)
	check(main.paused and main.original_results.elapsed == elapsed,"backgrounding freezes outcome presentation time")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(main.paused,"return preserves the interrupted outcome")
	var resumed_at := Time.get_ticks_usec()
	click(Vector2(280,205))
	check(not main.paused and main.screen == "result","Resume restores outcome instead of triggering Continue")
	key(false,KEY_SPACE)
	check(main.original_results.phase == "outcome","release held across an interruption cannot skip a source-ready outcome")
	await create_timer(0.1).timeout
	var foreground_seconds := (Time.get_ticks_usec()-resumed_at)/1000000.0
	check(main.original_results.elapsed > elapsed and main.original_results.elapsed-elapsed <= foreground_seconds+0.05,"outcome resumes without a background-time backlog")
	key(true,KEY_SPACE)
	key(false,KEY_SPACE)
	check(main.original_results.phase == "scores","fresh key release still invokes the original outcome skip")
	click(Vector2(278,362))
	check(main.screen == "game" and main.session.stage == 2,"fresh Continue input enters the next stage")
	# A deterministic two-player fixture, driven through actual platform input.
	main.players = 2
	main.session.start(42,1,1,2,2)
	main._show_round()
	main.touch_enabled = true
	main.touch.visible = true
	for id in 2:
		main.session.state.heroes[id].special_weapon = "mine"
		main.session.state.heroes[id].special_count = 5
	for code in [KEY_D,KEY_LEFT,KEY_SPACE,KEY_ENTER]:key(true,code)
	finger(7,main.touch._stick+Vector2(32,0),true)
	finger(8,main.touch._bomb,true)
	var remaining: int = main.session.remaining_ticks
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.touch.direction == Vector2i.ZERO and not main.touch.bomb_held,"interruption clears both captured touch fingers")
	await preload("res://tests/qa_capture.gd").capture(self,"interruption-paused-2p")
	main.touch.visible = false
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	click(Vector2(280,205))
	check(main.session.state.tick_number == 0 and not main.is_physics_processing(),"Resume itself cannot advance or re-enable fixture physics")
	# Force multiple physics callbacks into one display frame even on fast hosts.
	OS.delay_msec(100)
	await ticks(2)
	for id in 2:
		check(not main.session.state.heroes[id].moving and main.session.state.heroes[id].special_count == 5,"held movement and fire never replay for player %d" % (id+1))
	check(main.session.remaining_ticks == remaining-2,"only the two accepted 35 Hz updates consume round time")
	check(Engine.physics_ticks_per_second == 35,"platform lifecycle preserves the accepted 35 Hz clock")
	for code in [KEY_D,KEY_LEFT,KEY_SPACE,KEY_ENTER]:key(false,code)
	for code in [KEY_SPACE,KEY_ENTER]:key(true,code)
	await ticks(2)
	for id in 2:check(main.session.state.heroes[id].special_count == 4,"fresh player %d press fires exactly once" % (id+1))
	for code in [KEY_SPACE,KEY_ENTER]:key(false,code)
	# A fresh unconsumed touch must also be cancelled by hiding its controls.
	main.touch.visible = true
	finger(8,main.touch._bomb,true)
	main.touch.visible = false
	await ticks(2)
	check(main.session.state.heroes[0].special_count == 4,"hidden controls discard pending touch without a delayed action")
	var accepted_ticks: int = main.session.state.tick_number
	key(true,KEY_SPACE)
	key(true,KEY_P)
	key(false,KEY_P)
	click(Vector2(280,250))
	key(false,KEY_SPACE) # Menu consumes this release after the previous match.
	for i in 4:
		key(true)
		key(false)
		await process_frame
	check(main.screen == "game","new scene accepts fresh navigation after a held game key")
	key(true,KEY_SPACE)
	key(false,KEY_SPACE)
	await ticks(2)
	check(main.session.state.bombs.any(func(bomb: BombState):return bomb.owner_id == 0),"first fresh fire tap works after releasing the previous match key in a menu")
	key(true,KEY_P)
	key(false,KEY_P)
	click(Vector2(280,250))
	# Exercise the real preferences file in the runner's isolated user directory.
	main.save_enabled = true
	var expected_mute: bool = not main.audio.muted
	key(true,KEY_M)
	key(false,KEY_M)
	check(main.audio.muted == expected_mute,"visible sound input changes the saved preference")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(main.audio.muted == expected_mute,"interruption never changes the mute preference")
	main.queue_free()
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	check(main.audio.muted == expected_mute,"new application instance restores the mute preference")
	key(true,KEY_M)
	key(false,KEY_M)
	main.queue_free()
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	check(main.audio.muted == not expected_mute,"both mute values persist across application instances")
	print("INTERRUPTION_TRACE ",JSON.stringify({"passed":not failed,"paused_tick":tick,"outcome_paused_elapsed":elapsed,"two_player_accepted_ticks":accepted_ticks,"physics_hz":Engine.physics_ticks_per_second,"reloaded_muted":main.audio.muted,"tick_boundaries":tick_observations}))
	main.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	if not failed:print("INTERRUPTION_RENDER_OK")
	quit(1 if failed else 0)
