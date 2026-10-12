extends SceneTree
## Synthetic display schedules around the real application's fixed-step path.
## This measures invariance, not wall-clock frame throughput.

class RecordingRng extends OriginalRng:
	var values: Array[int] = []
	var limits: Array[int] = []
	func next(limit: int) -> int:
		var value := super.next(limit)
		values.append(value)
		limits.append(limit)
		return value

class PlaybackRng extends OriginalRng:
	var limits: Array[int] = []
	var origin := 0
	func next(limit: int) -> int:
		assert(calls-origin < limits.size(),"Replay exhausted its recorded random inputs")
		assert(limit == limits[calls-origin],"Replay changed its random-call bounds")
		return super.next(limit)

const TICKS := 260
const CASES := [["ordinary","",""],["rocket-grenade","rocket","grenade"],["mine-gas","mine","gas"],["fire-ice","fire","ice"]]
var main: Node2D
var failed := false
var report := {"boundary":"synthetic display callbacks, equal accepted simulation ticks; not elapsed-wall-time equivalence","scenarios":[]}

func _init() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func state_value(value: Variant) -> Variant:
	if value is OriginalRng:
		return {"calls":value.calls,"generator_state":str(value.generator.state),"generator_seed":str(value.generator.seed)}
	if value is Object:
		var fields := {}
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				fields[property.name] = state_value(value.get(property.name))
		return fields
	if value is Array:
		var values := []
		for element in value:values.append(state_value(element))
		return values
	if value is Dictionary:
		var fields := {}
		for key in value:fields[str(key)] = state_value(value[key])
		return fields
	if value is Vector2 or value is Vector2i:return [value.x,value.y]
	return value

func state_hash() -> String:
	return JSON.stringify(state_value(main.session),"",true,true).sha256_text()

func setup(entry: Array,recording: bool,tape: Dictionary = {}) -> void:
	for id in 2:
		for action in ["left","up","right","down","bomb"]:Input.action_release("p%d_%s" % [id+1,action])
	main.players = 2
	main.session.start(4242,1,1,2,2)
	for hero in main.session.state.heroes:hero.shield = 10000
	for id in 2:
		main.session.state.heroes[id].special_weapon = entry[id+1]
		main.session.state.heroes[id].special_count = 20 if entry[id+1] != "" else 0
	var old: OriginalRng = main.session.state.rng
	var rng: OriginalRng = RecordingRng.new() if recording else PlaybackRng.new()
	rng.generator.seed = old.generator.seed
	rng.generator.state = old.generator.state
	rng.calls = old.calls
	if not recording:
		rng.origin = old.calls
		rng.limits.assign(tape.limits)
		rng.recorded.resize(old.calls)
		rng.recorded.append_array(tape.values)
	main.session.state.rng = rng
	main._show_round()

func commands(tick: int) -> void:
	for id in 2:
		var direction: int = (tick/70+id*2)%4
		var firing: bool = (tick+id*35)%70 >= 35
		for index in 4:
			var action := "p%d_%s" % [id+1,["left","up","right","down"][index]]
			if index == direction and not firing:Input.action_press(action)
			else:Input.action_release(action)
		var fire := "p%d_bomb" % (id+1)
		if firing:Input.action_press(fire)
		else:Input.action_release(fire)

func finish_round() -> void:
	for id in [2,3]:main.session.state.heroes[id].alive = false
	commands(TICKS)
	main._physics_process(1.0/35)
	check(main.screen == "result","fixture enters the real outcome path")

func run_schedule(entry: Array,tape: Dictionary,hz: int,stalls: bool) -> Dictionary:
	setup(entry,false,tape)
	var ticks := 0
	var frames := 0
	var accumulator := 0.0
	var checkpoints := []
	while ticks < TICKS:
		var delta := 0.12 if stalls and frames%37 == 20 else 1.0/hz
		accumulator += delta*35
		while accumulator >= 1.0-0.0000001 and ticks < TICKS:
			commands(ticks)
			main._physics_process(1.0/35)
			ticks += 1
			accumulator -= 1.0
			if ticks%35 == 0 or ticks == TICKS:checkpoints.append({"tick":ticks,"sha256":state_hash()})
		main._process(delta)
		main.view._process(delta)
		for child in main.view.get_children():
			if child is HeroView:child._process(delta)
		# Negative control used only when validating this checker itself.
		if OS.get_environment("BOMB_IT_PACING_MUTATION") == "timer":main.session.remaining_ticks -= 1
		frames += 1
	check(main.session.state.tick_number == TICKS,"display callbacks never add simulation ticks")
	finish_round()
	var stopped := state_hash()
	for frame in hz*6:
		main._process(1.0/hz)
		if frame%hz < 35:main._physics_process(1.0/35)
	check(main.original_results.phase == "scores","outcome presentation reaches the original score screen")
	check(state_hash() == stopped,"outcome animation, audio and score display never change authoritative state")
	check(main.session.state.rng.calls-main.session.state.rng.origin == tape.values.size(),"all recorded random inputs are consumed exactly")
	return {"requested_display_hz":hz,"bounded_stall_ms":120 if stalls else 0,"display_callbacks":frames,"accepted_ticks":TICKS+1,"checkpoints":checkpoints,"result_state_sha256":stopped}

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	for entry in CASES:
		setup(entry,true)
		var events := {}
		for tick in TICKS:
			commands(tick)
			main._physics_process(1.0/35)
			for event in main.session.state.events:events[event] = events.get(event,0)+1
		for event in (["place","explode"] if entry[0] == "ordinary" else entry.slice(1)):
			check(events.get(event,0) > 0,"recording exercises %s: %s" % [entry[0],event])
		finish_round()
		var rng: RecordingRng = main.session.state.rng
		var tape := {"values":rng.values.duplicate(),"limits":rng.limits.duplicate()}
		var runs := []
		for schedule in [[35,false],[60,false],[120,false],[60,true],[120,true]]:
			var result := run_schedule(entry,tape,schedule[0],schedule[1])
			if not runs.is_empty():
				check(result.checkpoints == runs[0].checkpoints and result.result_state_sha256 == runs[0].result_state_sha256,"schedule invariance: %s at %d Hz stalls=%s" % [entry[0],schedule[0],schedule[1]])
			runs.append(result)
			await process_frame
		report.scenarios.append({"name":entry[0],"seed":4242,"observed_events":events,"commands":"direction=(tick/70+player*2)%4 while moving; stationary fire=(tick+player*35)%70>=35","recorded_random":tape,"runs":runs})
	report.passed = not failed
	report.engine = Engine.get_version_info().string
	report.revision = OS.get_environment("BOMB_IT_REVISION")
	report.build = JSON.parse_string(OS.get_environment("BOMB_IT_BUILD_METADATA"))
	var path := OS.get_environment("BOMB_IT_PACING_REPORT")
	if path != "":
		var file := FileAccess.open(path,FileAccess.WRITE)
		check(file != null,"pacing report is writable")
		if file != null:file.store_string(JSON.stringify(report,"  ",true,true))
	main.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	if not failed:print("PACING_OK")
	quit(1 if failed else 0)
