extends Node
## Opt-in release smoke: real inputs and simulation, with verified isolated saves.
var main: Node
var output := ""
var phase := ""
var report := {"passed":true,"checks":[],"editor":false,"debug_build":false}

func _ready() -> void:call_deferred("run")

func check(value: bool, message: String) -> bool:
	report.checks.append({"passed":value,"message":message})
	if not value:
		report.passed = false
		push_error(message)
	return value

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(code: Key) -> void:
	key(code,true)
	key(code,false)

func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = main.get_global_transform_with_canvas()*point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event,true)
	await get_tree().process_frame

func capture(name_text: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(name_text+".png")) == OK,"rendered capture saved: "+name_text)

func ticks(count: int) -> void:
	var target: int = main.session.state.tick_number+count
	var deadline := Time.get_ticks_msec()+3000
	while main.session.state.tick_number < target and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	check(main.session.state.tick_number >= target,"automatic simulation advances accepted ticks")

func run() -> void:
	output = OS.get_environment("BOMB_IT_SMOKE_OUTPUT")
	phase = OS.get_environment("BOMB_IT_SMOKE_PHASE")
	var expected := OS.get_environment("BOMB_IT_SMOKE_USER_ROOT").replace("\\","/").simplify_path().to_lower()
	var actual := OS.get_user_data_dir().replace("\\","/").simplify_path().to_lower()
	# Fail closed before input can toggle sound or save any match preferences.
	if expected.is_empty() or not expected.is_absolute_path() or not actual.begins_with(expected+"/") or output.is_empty() or phase not in ["play","reload"]:
		push_error("Package smoke requires a verified isolated user-data root and output")
		get_tree().quit(1)
		return
	report.editor = OS.has_feature("editor")
	report.debug_build = OS.is_debug_build()
	report.engine = Engine.get_version_info().string
	report.executable = OS.get_executable_path()
	report.user_data_dir = OS.get_user_data_dir()
	report.phase = phase
	check(not report.editor and not report.debug_build,"actual exported release contains no editor/debug build")
	check(Engine.physics_ticks_per_second == 35,"export retains 35 Hz simulation")
	check(main.screen == "menu","normal startup reaches original title screen")
	await capture(phase+"-menu")
	if phase == "reload":
		check(main.audio.muted,"second process restores the saved mute preference")
		await finish()
		return
	check(not main.audio.muted,"fresh isolated profile begins unmuted")
	press(KEY_M)
	check(main.audio.muted,"real menu input toggles sound and saves preference")
	await click(Vector2(477,100))
	await click(Vector2(470,155))
	await click(Vector2(477,135))
	if not check(main.screen == "select","original menu route reaches character selection"):
		await finish()
		return
	press(KEY_SPACE)
	if not check(main.screen == "game","selection release starts a real match"):
		await finish()
		return
	var start: Vector2i = main.session.state.heroes[0].cell
	key(KEY_D,true)
	await ticks(8)
	key(KEY_D,false)
	await ticks(8)
	check(main.session.state.heroes[0].cell != start,"keyboard movement changes the human's arena cell")
	report.initial_cell = [start.x,start.y]
	var current: Vector2i = main.session.state.heroes[0].cell
	report.moved_cell = [current.x,current.y]
	key(KEY_SPACE,true)
	await ticks(2)
	key(KEY_SPACE,false)
	check(main.session.state.bombs.any(func(bomb):return bomb.owner_id == 0),"keyboard fire places a human-owned bomb")
	await capture("play-match")
	press(KEY_ESCAPE)
	check(main.paused,"Escape pauses the exported match")
	var paused_tick: int = main.session.state.tick_number
	await get_tree().create_timer(0.2).timeout
	check(main.session.state.tick_number == paused_tick,"paused match consumes no simulation ticks")
	await capture("play-paused")
	await click(Vector2(300,207))
	check(not main.paused,"rendered Resume button resumes the match")
	await ticks(3)
	report.accepted_ticks = main.session.state.tick_number
	await finish()

func finish() -> void:
	var file := FileAccess.open(output.path_join(phase+".json"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write exported smoke report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report,"  ",true,true))
	file.close()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	if report.passed:print("PACKAGE_SMOKE_OK ",phase)
	get_tree().quit(0 if report.passed else 1)
