extends SceneTree
var failed := false
func _init() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func click(main: Node2D, point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = main.position + point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
func run() -> void:
	root.size = Vector2i(550,400)
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	main.session.start(42,1,1,1)
	main._show_round()
	for id in [1,2,3]:
		main.session.state.heroes[id].alive = false
	main._physics_process(1.0/35)
	var total: int = main.session.totals[0]
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var blank := root.get_texture().get_image()
	main._process(5.0/35.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var before_frame_seven := root.get_texture().get_image()
	check(blank.get_data() == before_frame_seven.get_data(),"source banner remains absent through frame6")
	await process_frame
	click(main,Vector2(300,243))
	check(main.session.stage == 1 and main.screen == "result", "outcome cannot continue before source banner readiness")
	check(main.session.totals[0] == total, "outcome input never reapplies score awards")
	main._process(63.0/35.0)
	var released := InputEventKey.new()
	released.keycode = KEY_SPACE
	released.pressed = false
	root.push_input(released,true)
	check(main.original_results.phase == "outcome","source key-up skip is unavailable before banner frame70")
	main._process(1.0/35.0+0.00001)
	root.push_input(released,true)
	check(main.original_results.phase == "scores","source key-up skip becomes available at banner frame70")
	check(main.session.totals[0] == total,"skipping outcome never awards twice")
	for humans in [1,2]:
		for outcome in ["win","lose","timeup_win","timeup_lose","exhausted","complete"]:
			main.players = humans
			main.session.start(42,1,1,humans,2)
			if outcome == "complete":main.session.stage = main.session.total_stages
			main._show_round()
			if outcome in ["win","complete"]:
				for id in range(humans,4):main.session.state.heroes[id].alive = false
			elif outcome in ["lose","exhausted"]:
				for id in humans:
					main.session.state.heroes[id].alive = false
					main.session.state.heroes[id].lives = 0 if outcome == "exhausted" else 2
			else:
				main.session.remaining_ticks = 1
				main.session.state.heroes[0].score = 100 if outcome == "timeup_win" else 0
			main._physics_process(1.0/35)
			var totals: Array = main.session.totals.duplicate()
			var tick: int = main.session.state.tick_number
			var stage: int = main.session.stage
			if outcome == "timeup_lose":
				var living: Array = []
				for child in main.view.get_children():
					if child is HeroView and child.actor.id < humans:
						living.append(child)
						check(child.actor.alive and child.death.visible and not child.smoke.visible,"time-up loss replaces surviving human with heroExp alone")
				await preload("res://tests/qa_capture.gd").capture(self,"timeout-death-%dp-start" % humans)
				for i in 10:main._physics_process(1.0/35)
				for child in living:
					var age: int = child.death_age
					main._show_result()
					check(child.death_age == age,"repeated result cannot restart time-up death")
				await preload("res://tests/qa_capture.gd").capture(self,"timeout-death-%dp-tick10" % humans)
				for i in 25:main._physics_process(1.0/35)
				for child in living:
					check(not child.visible and child.actor.alive,"time-up death retires without changing authoritative alive state")
				check(main.session.state.tick_number == tick and main.session.totals == totals,"time-up death presentation cannot tick or award")
				await preload("res://tests/qa_capture.gd").capture(self,"timeout-death-%dp-retired" % humans)
			main._process(5.499)
			check(main.original_results.phase == "outcome", "source 5500ms deadline not rounded down: %dP %s" % [humans,outcome])
			await preload("res://tests/qa_capture.gd").capture(self,"outcome-%dp-%s" % [humans,outcome])
			main._process(0.0011)
			var terminal: bool = outcome in ["exhausted","complete"]
			check(main.original_results.phase == ("final" if terminal else "scores"), "correct continuation route: %dP %s" % [humans,outcome])
			await preload("res://tests/qa_capture.gd").capture(self,"score-%dp-%s" % [humans,outcome])
			main._show_result()
			main._process(10)
			for i in 80:main._physics_process(1.0/35)
			check(main.session.totals == totals and main.session.state.tick_number == tick,"result display is read-only: %dP %s" % [humans,outcome])
			await process_frame
			if terminal:
				main.session.next_round()
				check(main.session.stage == stage and main.session.result != "", "terminal campaigns cannot continue")
				click(main,Vector2(200,379))
				click(main,Vector2(200,379))
				check(main.screen == "game" and main.session.stage == 1,"terminal replay starts exactly once")
			else:
				click(main,Vector2(278,362))
				var next_state: GameState = main.session.state
				click(main,Vector2(278,362))
				check(main.screen == "game" and main.session.state == next_state,"repeated continue cannot rebuild a round")
				check(main.session.stage == stage+(1 if outcome.ends_with("win") else 0),"retry/next stage preserves campaign route")
	# Match the original-bytecode score fixture exactly after its 100s win.
	for humans in [1,2]:
		main.players = humans
		main.session.start(42,1,1,humans,2)
		main.session.remaining_ticks = 3501
		for id in humans:
			main.session.totals[id] = 1000
			main.session.state.heroes[id].score = 1110
			main.session.state.heroes[id].kill_score = 1000
			main.session.state.heroes[id].destruction_score = 110
		main._show_round()
		for id in range(humans,4):main.session.state.heroes[id].alive = false
		main._physics_process(1.0/35)
		main._process(5.5)
		check(main.session.state.heroes[0].score == 3110 and main.session.totals[0] == 4110,"source fixture score and total agree without display awards")
		await preload("res://tests/qa_capture.gd").capture(self,"source-score-%dp" % humans)
	# The public runner provides a private user:// directory. Verify actual saved
	# best score survives a new main scene, not just an in-memory preference.
	main.save_enabled = true
	main.players = 1
	main.session.start(42,1,1,1)
	main._show_round()
	main.session.state.heroes[0].score = 12345
	for id in [1,2,3]:main.session.state.heroes[id].alive = false
	main._physics_process(1.0/35)
	var saved: int = main.high_score
	main.queue_free()
	await process_frame
	var reopened = load("res://scenes/main.tscn").instantiate()
	root.add_child(reopened)
	check(reopened.high_score == saved,"local best score survives scene restart")
	reopened.queue_free()
	await process_frame
	await create_timer(1).timeout
	if not failed:print("RESULT_RENDER_OK")
	quit(1 if failed else 0)
