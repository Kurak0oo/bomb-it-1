extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("run")

func snapshot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func changed(before: Image, after: Image, area: Rect2i) -> int:
	var count := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if before.get_pixel(x,y) != after.get_pixel(x,y):
				count += 1
	return count

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func run() -> void:
	root.size = Vector2i(550,400)
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	main.set_physics_process(false)
	root.add_child(main)
	main.set_physics_process(false)
	main.audio.muted = true
	main.session.start(42, 1, 1, 1)
	main._show_round()
	main.view.frozen = true
	await process_frame
	await process_frame
	var before := await snapshot()
	main.session.totals[0] = 98765
	main._update_hud()
	var after := await snapshot()
	await preload("res://tests/qa_capture.gd").capture(self, "hud-base")
	check(changed(before, after, Rect2i(0,0,85,290)) == 0, "original HUD shows round score, independently of accumulated campaign totals")
	main.session.state.heroes[0].score = 12345
	main._update_hud()
	var scored := await snapshot()
	check(changed(after, scored, Rect2i(30,60,42,15)) > 10, "round score changes in Symbol 536's original score field")
	var hero: HeroState = main.session.state.heroes[0]
	hero.armor = true
	main._update_hud()
	var shield := await snapshot()
	check(changed(scored, shield, Rect2i(67,23,15,16)) > 5, "shield possession appears in its recovered HUD icon slot")
	hero.lives = 0
	main._update_hud()
	var eliminated := await snapshot()
	check(changed(shield, eliminated, Rect2i(17,21,35,32)) > 50, "zero lives dims the original portrait panel")
	await preload("res://tests/qa_capture.gd").capture(self, "hud-status")
	# Source-style fixtures preserve all five floor/brick/center families. Seed
	# search selects generated themes; it does not claim Flash RNG seed parity.
	for theme in 5:
		for seed_value in 100:
			main.session.start(seed_value,1,1,1)
			if main.session.state.scene_style == theme:
				break
		check(main.session.state.scene_style == theme, "fixture selects theme %d" % theme)
		main._show_round()
		main.view.frozen = true
		await process_frame
		await preload("res://tests/qa_capture.gd").capture(self, "arena-theme-%d-native" % theme)
		root.size = Vector2i(1600,800)
		await process_frame
		await preload("res://tests/qa_capture.gd").capture(self, "arena-theme-%d-landscape" % theme)
		root.size = Vector2i(550,400)
		await process_frame
		# Controlled crossing composition: two robots and bombs on opposite sides
		# of the central scenery, plus low fire and high ice at adjacent cells.
		var state: GameState = main.session.state
		for y in 13:
			for x in 15:
				if x not in [6,7] or y not in [5,6]:
					state.cell_at(Vector2i(x,y)).kind = GameState.Kind.FLOOR
		for id in 4:
			state.heroes[id].cell = [Vector2i(6,4),Vector2i(6,7),Vector2i(4,6),Vector2i(9,6)][id]
			state.heroes[id].shield = 0
			state.heroes[id].shielded_this_tick = false
		state.bombs.append(BombState.new(Vector2i(7,4)))
		state.bombs.append(BombState.new(Vector2i(7,7)))
		for kind in ["fire","ice"]:
			var effect := SpecialState.new(kind,state.heroes[0])
			effect.painted.assign([Vector2i(5,5),Vector2i(5,6)] if kind == "fire" else [Vector2i(8,5),Vector2i(8,6)])
			effect.born = [0,0]
			effect.age = 8
			state.specials.append(effect)
		main._show_round()
		main.view.frozen = true
		await process_frame
		await preload("res://tests/qa_capture.gd").capture(self, "arena-theme-%d-crossing" % theme)
	main.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	if not failed:
		print("HUD_RENDER_OK")
	quit(1 if failed else 0)
