extends SceneTree
## Engine submission and injected-input instrumentation. No physical presentation claim.
const FIELDS := ["submission_interval_ms","process_delta_ms","physics_cpu_ms","static_memory_bytes","nodes","draw_calls"]
const SCENARIOS := [["ordinary","",""],["rocket-grenade","rocket","grenade"],["mine-gas","mine","gas"],["fire-ice","fire","ice"],["outcome","",""],["pickups","",""]]
var main: Node2D
var hz := 60
var duration := 48.0
var warmup := 3.0
var started := 0
var phase_started := 0
var phase := -1
var phase_serial := 0
var phase_events: Array = []
var inputs: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var awaiting_submission: Array[Dictionary] = []
var frame_columns: Dictionary = {}
var frame_count := 0
var capacity := 0
var physics_us := 0
var next_input := 0
var input_number := 0

func _init() -> void:call_deferred("run")

func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func begin_phase(index: int) -> void:
	for sample in pending:sample.closed_reason = "scene_ended"
	for sample in awaiting_submission:sample.closed_reason = "scene_changed_before_submission"
	pending.clear()
	awaiting_submission.clear()
	for code in [KEY_A,KEY_W,KEY_D,KEY_S,KEY_SPACE,KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_ENTER]:key(code,false)
	phase = index
	phase_serial += 1
	phase_started = Time.get_ticks_usec()
	main.players = 2
	main.session.start(4242+index,1,1,2,2)
	for hero in main.session.state.heroes:hero.shield = 10000
	for id in 2:
		main.session.state.heroes[id].special_weapon = SCENARIOS[index][id+1]
		main.session.state.heroes[id].special_count = 1000 if SCENARIOS[index][id+1] != "" else 0
	if index == 5:
		main.session.state.heroes[0].cell = Vector2i(1,1)
		for x in range(1,10):
			var cell: CellState = main.session.state.cell_at(Vector2i(x,1))
			cell.kind = GameState.Kind.FLOOR
			cell.item = ["bomb","power","shoe","glove","shield","life"][x-2] if x >= 2 and x <= 7 else ""
	main._show_round()
	main.touch_enabled = true
	main.touch.visible = true
	phase_events.append({"scenario":SCENARIOS[index][0],"start_us":phase_started,"setup_cpu_ms":(Time.get_ticks_usec()-phase_started)/1000.0,"events":{},"peak_bombs":0,"peak_specials":0,"accepted_ticks":0,"screens":[]})
	next_input = Time.get_ticks_usec()+100000
	input_number = 0

func inject(now: int) -> void:
	for previous in pending:previous.closed_reason = "superseded_by_new_input"
	pending.clear()
	var actor: HeroState = main.session.state.heroes[0]
	if phase == 5:
		key(KEY_D,true)
		next_input = now+10000000
		return
	var sample := {"kind":"move" if input_number%2 == 0 else "fire","phase_serial":phase_serial,"scenario":SCENARIOS[phase][0],"dispatch_us":now,"dispatch_tick":main.session.state.tick_number,"delivered_us":null,"feedback_submission_us":null,"state_feedback_us":null,"source_wait_ticks":null,"gate_at_dispatch":"moving" if actor.moving else "ready","direction":SimRules.direction((input_number/2)%4),"position":actor.pixel_position(),"special_count":actor.special_count,"bomb_ids":[]}
	if actor.stop_ticks > 0:sample.gate_at_dispatch = "frozen"
	elif sample.kind == "fire" and actor.bombs_available == 0 and actor.special_count == 0:sample.gate_at_dispatch = "bomb-capacity"
	elif sample.kind == "move" and not actor.moving:
		var destination: CellState = main.session.state.cell_at(actor.cell+sample.direction)
		if destination == null or destination.kind != GameState.Kind.FLOOR or destination.bomb != null:sample.gate_at_dispatch = "blocked-tile"
	for bomb in main.session.state.bombs:
		if bomb.owner_id == 0:sample.bomb_ids.append(bomb.get_instance_id())
	inputs.append(sample)
	pending.append(sample)
	for code in [KEY_A,KEY_W,KEY_D,KEY_S]:key(code,false)
	if sample.kind == "move":
		key(KEY_SPACE,false)
		key([KEY_A,KEY_W,KEY_D,KEY_S][(input_number/2)%4],true)
	else:
		key(KEY_SPACE,true)
	# The second human contributes concurrent movement and fire load.
	for code in [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN]:key(code,false)
	key(KEY_ENTER,input_number%2 == 0)
	if input_number%2 != 0:key([KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN][(input_number/3+2)%4],true)
	input_number += 1
	next_input = now+350000

func simulate() -> void:
	if not is_instance_valid(main):return
	var tick: int = main.session.state.tick_number
	var before := Time.get_ticks_usec()
	main._physics_process(1.0/35)
	var after := Time.get_ticks_usec()
	physics_us += after-before
	if main.session.state.tick_number == tick:return
	var load: Dictionary = phase_events.back()
	load.accepted_ticks += 1
	load.peak_bombs = maxi(load.peak_bombs,main.session.state.bombs.size())
	load.peak_specials = maxi(load.peak_specials,main.session.state.specials.size())
	for event in main.session.state.events:load.events[event] = load.events.get(event,0)+1
	var actor: HeroState = main.session.state.heroes[0]
	for sample in pending.duplicate():
		if sample.phase_serial != phase_serial or sample.state_feedback_us != null or sample.has("closed_reason"):continue
		if sample.delivered_us == null:
			sample.delivered_us = after
			sample.delivery_tick = main.session.state.tick_number
		var feedback: bool = actor.moving and actor.direction == sample.direction and actor.pixel_position() != sample.position
		if sample.kind == "fire":
			feedback = actor.special_count < sample.special_count
			for bomb in main.session.state.bombs:
				if bomb.owner_id == 0 and not sample.bomb_ids.has(bomb.get_instance_id()):feedback = true
		if feedback:
			sample.state_feedback_us = after
			sample.source_wait_ticks = main.session.state.tick_number-int(sample.delivery_tick)
			awaiting_submission.append(sample)
			pending.erase(sample)

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	hz = int(arguments[0])
	duration = float(arguments[1])
	warmup = float(arguments[2])
	Engine.max_fps = hz
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_physics_process(false)
	begin_phase(0)
	# Fixed-state diagnostic; outside the measured frame interval.
	var hud_microseconds := []
	for batch in 10:
		var before := Time.get_ticks_usec()
		for repeat in 100:main.original_hud.sync(main.session)
		hud_microseconds.append((Time.get_ticks_usec()-before)/100.0)
	capacity = int((duration+warmup)*hz*2)+4096
	for field in FIELDS:
		var column := PackedFloat64Array()
		column.resize(capacity)
		frame_columns[field] = column
	physics_frame.connect(simulate)
	started = Time.get_ticks_usec()
	phase_started = started
	var last_submission := started
	var first_measured_submission := 0
	while (Time.get_ticks_usec()-started)/1000000.0 < duration+warmup:
		await process_frame
		var now := Time.get_ticks_usec()
		if (now-phase_started)/1000000.0 >= 8.0:begin_phase((phase+1)%SCENARIOS.size())
		var screen_phase: String = main.screen+":"+main.original_results.phase if main.screen == "result" else main.screen
		if not phase_events.back().screens.has(screen_phase):phase_events.back().screens.append(screen_phase)
		if phase == 4 and main.screen == "game" and now-phase_started > 1000000:
			for id in [2,3]:main.session.state.heroes[id].alive = false
		if now >= next_input and main.screen == "game" and not main.paused:inject(now)
		await RenderingServer.frame_post_draw
		var submitted := Time.get_ticks_usec()
		for sample in awaiting_submission:sample.feedback_submission_us = submitted
		awaiting_submission.clear()
		if (submitted-started)/1000000.0 >= warmup:
			if frame_count >= capacity:
				push_error("Preallocated performance sample capacity exceeded")
				quit(1)
				return
			if first_measured_submission == 0:first_measured_submission = submitted
			var values := [(submitted-last_submission)/1000.0,main.get_process_delta_time()*1000,physics_us/1000.0,Performance.get_monitor(Performance.MEMORY_STATIC),Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
			for index in FIELDS.size():frame_columns[FIELDS[index]][frame_count] = values[index]
			frame_count += 1
		physics_us = 0
		last_submission = submitted
	physics_frame.disconnect(simulate)
	var frames := []
	for index in frame_count:
		var row := {}
		for field in FIELDS:row[field] = frame_columns[field][index]
		frames.append(row)
	var measured_inputs := []
	for sample in inputs:
		if sample.dispatch_us < started+int(warmup*1000000):continue
		if sample.state_feedback_us == null and not sample.has("closed_reason"):sample.closed_reason = "scene_or_measurement_ended"
		sample.erase("bomb_ids")
		sample.erase("position")
		sample.erase("direction")
		measured_inputs.append(sample)
	var metadata: Dictionary = JSON.parse_string(OS.get_environment("BOMB_IT_BUILD_METADATA"))
	metadata.merge({"engine":Engine.get_version_info().string,"os":OS.get_name(),"os_version":OS.get_version(),"cpu":OS.get_processor_name(),"renderer":RenderingServer.get_video_adapter_name(),"reported_screen_refresh_hz":DisplayServer.screen_get_refresh_rate(),"requested_max_fps":hz,"vsync_requested":"disabled","physics_hz":Engine.physics_ticks_per_second,"warmup_seconds":warmup,"requested_measurement_seconds":duration,"first_measured_submission_us":first_measured_submission,"last_measured_submission_us":last_submission,"hud_sync_us_per_call_batches":hud_microseconds,"frame_storage_preallocated_bytes":capacity*FIELDS.size()*8,"input_observer_records":inputs.size(),"measurement":"frame_post_draw callbacks are render submissions, not measured scanout; input timestamps start at synthetic dispatch"})
	var file := FileAccess.open(arguments[3],FileAccess.WRITE)
	if file == null:
		push_error("Cannot write performance capture")
		quit(1)
		return
	file.store_string(JSON.stringify({"metadata":metadata,"target_hz":hz,"frames":frames,"inputs":measured_inputs,"scenarios":phase_events},"",true,true))
	main.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	print("PERFORMANCE_CAPTURE_OK frames=",frame_count)
	quit()
