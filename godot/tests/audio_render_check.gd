extends SceneTree

var failed := false
var main: Node2D

func _init() -> void:call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func play_cues(names: Array[String]) -> void:main.audio.events(names)

func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = main.get_global_transform_with_canvas() * point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)

func peak(capture: AudioEffectCapture) -> float:
	var value := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		value = maxf(value,maxf(absf(sample.x),absf(sample.y)))
	return value

func run() -> void:
	root.size = Vector2i(550,400)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_physics_process(false)
	await create_timer(0.3).timeout
	check(main.audio.music.playing,"menu starts the recovered soundtrack")
	var menu_position: float = main.audio.music.get_playback_position()
	key(KEY_DOWN)
	key(KEY_ENTER)
	check(main.screen == "help","public menu navigation enters help")
	key(KEY_ESCAPE)
	check(main.screen == "menu" and main.audio.music.get_playback_position() >= menu_position,"returning from help preserves the ongoing menu soundtrack")
	key(KEY_M)
	check(main.audio.muted and not main.audio.music.playing,"mute stops the soundtrack instead of advancing it silently")
	await create_timer(0.2).timeout
	key(KEY_M)
	check(not main.audio.muted and main.audio.music.playing,"unmute starts the current soundtrack")
	check(main.audio.music.get_playback_position() < 0.1,"unmute restarts the soundtrack at its beginning")
	for i in 4:
		key(KEY_ENTER)
		await process_frame
	check(main.screen == "game","public input reaches the round")
	await create_timer(0.2).timeout
	key(KEY_P)
	var paused_position: float = main.audio.music.get_playback_position()
	await create_timer(0.2).timeout
	check(main.paused and not main.audio.music.stream_paused,"ordinary pause leaves source music running")
	check(main.audio.music.get_playback_position() > paused_position,"music progresses during ordinary pause")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(main.audio.music.stream_paused,"interrupted audio waits for deliberate resume even after focus returns")
	key(KEY_P)
	check(not main.paused and not main.audio.music.stream_paused,"deliberate resume restores interrupted audio")
	var previous_music: String = main.audio.music.stream.resource_path
	main.session.remaining_ticks = 1
	var tick: int = main.session.state.tick_number
	main.set_physics_process(true)
	while main.session.state.tick_number == tick:await physics_frame
	main.set_physics_process(false)
	check(main.screen == "result" and main.session.result == "timeup_lose","fixture reaches retryable loss through the application")
	check(main.audio.music.stream.resource_path.ends_with("407_Bombit_-_mission_failed.mp3"),"loss changes to source mission-failed cue")
	check(main.audio.music.stream.loop,"outcome retains source onSoundComplete restart")
	await create_timer(2.0).timeout
	key(KEY_SPACE)
	check(not main.audio.music.playing,"nonterminal score sheet stops outcome music")
	click(Vector2(278,362))
	check(main.screen == "game" and main.session.stage == 1,"Continue retries the same stage")
	check(main.audio.music.stream.resource_path == previous_music,"source frame-2 retry restarts the same selected soundtrack")
	check(main.audio.music.get_playback_position() < 0.1,"retry restarts the selected track at the beginning")
	for id in [1,2,3]:main.session.state.heroes[id].alive = false
	tick = main.session.state.tick_number
	main.set_physics_process(true)
	while main.session.state.tick_number == tick:await physics_frame
	main.set_physics_process(false)
	check(main.audio.music.stream.resource_path.ends_with("405_Bombit_-_level_complete.mp3"),"win selects the recovered level-complete track")
	await create_timer(2.0).timeout
	key(KEY_SPACE)
	click(Vector2(278,362))
	check(main.session.stage == 2 and main.audio.music.stream.resource_path != previous_music,"source frame-1 next stage advances soundtrack selection")
	play_cues(["explode","explode","place"])
	check(main.audio.voices.filter(func(voice):return voice.playing).size() == 3,"duplicate cue starts overlap with the next cue instead of being deduplicated")
	play_cues(["explode","explode","explode","explode","explode","explode"])
	check(main.audio.voices.filter(func(voice):return voice.playing).size() == 9,"a ninth source cue preserves the eight already playing tails")
	key(KEY_M)
	var tails: int = main.audio.voices.filter(func(voice):return voice.playing).size()
	play_cues(["pickup"])
	check(main.audio.voices.filter(func(voice):return voice.playing).size() == tails,"mute gates new effects without cutting existing tails")
	var rng_calls: int = main.session.state.rng.calls
	var rng_state: int = main.session.state.rng.generator.state
	# Independent original full-Sprite564 control: draws [3,1,2,3]
	# force the prior-last==new-first branch and return [1,2,3,4].
	var music_rng := OriginalRng.new(1)
	music_rng.recorded = [3,1,2,3,0,1,2,3]
	main.audio.music_rng = music_rng
	main.audio.new_campaign()
	var tracks: Array[String] = []
	for i in 8:
		main.audio.play_round_music()
		tracks.append(main.audio.music.stream.resource_path)
	for start in [0,4]:
		var unique := {}
		for path in tracks.slice(start,start+4):unique[path] = true
		check(unique.size() == 4,"each presentation playlist visits all four source tracks")
	for i in 4:check(tracks[i] == GameAudio.PATH+GameAudio.ROUND_TRACKS[i],"forced source boundary case selects the observed track order")
	check(tracks[3] != tracks[4],"source boundary swap avoids a repeat between playlists")
	check(main.session.state.rng.calls == rng_calls and main.session.state.rng.generator.state == rng_state,"audio choices never draw from or change gameplay RNG")
	print("AUDIO_MUSIC_TRACE ",JSON.stringify({"tracks":tracks,"gameplay_calls_before":rng_calls,"gameplay_calls_after":main.session.state.rng.calls}))
	main.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	# A native mixer control avoids assuming decoder/sample quantization across
	# Windows and Linux. Source Sound defaults to unity gain (no setVolume).
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0,capture)
	var control := AudioStreamPlayer.new()
	control.stream = load(GameAudio.PATH+GameAudio.EFFECTS.explode)
	root.add_child(control)
	control.play()
	await create_timer(0.6).timeout
	var expected_peak := peak(capture)
	capture.clear_buffer()
	var subject := GameAudio.new()
	root.add_child(subject)
	subject.events(["explode"])
	await create_timer(0.6).timeout
	var actual_peak := peak(capture)
	check(expected_peak > 0 and actual_peak == expected_peak,"recovered effect reaches the source unity gain through the actual mixer")
	print("AUDIO_GAIN_TRACE ",JSON.stringify({"control_peak":expected_peak,"actual_peak":actual_peak}))
	await subject.retire()
	subject.queue_free()
	control.queue_free()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	await process_frame
	if not failed:print("AUDIO_RENDER_OK")
	quit(1 if failed else 0)
