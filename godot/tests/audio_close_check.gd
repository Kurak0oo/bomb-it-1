extends SceneTree

var main: Node2D
var closing_tick := -1
var closing_voices := 0

func _init() -> void:call_deferred("run")

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_physics_process(false)
	var mode := OS.get_environment("BOMB_IT_CLOSE_MODE")
	if mode != "menu":
		for i in 4:
			key(KEY_ENTER)
			await process_frame
		# Include a genuine effect playback in the draining set.
		key(KEY_SPACE)
		main.set_physics_process(true)
		while main.session.state.tick_number == 0:await physics_frame
		main.set_physics_process(false)
		if mode == "paused":key(KEY_P)
		if mode == "background":root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		if mode == "muted":key(KEY_M)
	root.close_requested.connect(func():
		if closing_tick >= 0:return
		closing_tick = main.session.state.tick_number if main.session.state != null else 0
		closing_voices = main.audio.voices.filter(func(v):return v.playing).size()
		# Pending input cannot create new work while the quit coroutine drains.
		key(KEY_SPACE)
		key(KEY_ENTER))
	print("AUDIO_CLOSE_READY ",JSON.stringify({"mode":mode,"screen":main.screen,"paused":main.paused,"muted":main.audio.muted,"suspended":main.audio.suspended,"voices":main.audio.voices.filter(func(v):return v.playing).size()}))

func _process(_delta: float) -> bool:
	if closing_tick >= 0 and is_instance_valid(main):
		if main.session.state != null and main.session.state.tick_number != closing_tick:push_error("Closing advanced gameplay")
		if main.audio.voices.filter(func(v):return v.playing).size() > closing_voices:push_error("Closing started another effect")
	return false
