extends SceneTree
## Source endpoint: parent-created tick 18 / preinstalled tick 17 (age 18).
var failed := false

func _init() -> void:
	call_deferred("run")

func snapshot(view: GameView) -> Image:
	view.sync_view()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func count_kind(state: GameState, kind: String) -> int:
	var count := 0
	for effect in state.specials:
		if effect.kind == kind:
			count += 1
	return count

func run() -> void:
	root.size = Vector2i(550,400)
	for initial in [false,true]:
		for direction in 4:
			var state := GameState.new()
			var rows := PackedStringArray()
			for y in 13:
				rows.append("...............")
			state.setup(rows)
			for actor in state.heroes:
				actor.alive = false
				actor.death_ticks = 999
			var owner := state.heroes[0]
			owner.cell = Vector2i(8,6)
			owner.facing = direction
			owner.special_weapon = "grenade"
			owner.special_count = 3
			var view := GameView.new()
			view.state = state
			view.frozen = true
			root.add_child(view)
			var blank := await snapshot(view)
			if initial:
				SpecialRules.place(state,owner)
				state.specials.back().just_placed = false
			else:
				owner.alive = true
				var fire := PlayerCommands.new()
				fire.bomb_requested = true
				state.tick([fire])
				owner.alive = false
			for i in 17:
				state.tick([])
			var before := await snapshot(view)
			check(count_kind(state,"grenade") == 1 and count_kind(state,"pulse") == 0,"Grenade remains visible through body frame 18")
			check(before.get_data() != blank.get_data(),"Airborne grenade must render before endpoint")
			if direction == 2:
				await preload("res://tests/qa_capture.gd").capture(self,"grenade-%s-before" % ("initial" if initial else "input"))
			state.tick([])
			var endpoint := await snapshot(view)
			check(count_kind(state,"grenade") == 0 and count_kind(state,"pulse") == 5,"Source final-frame callback replaces grenade with five pulses")
			check(endpoint.get_data() != before.get_data() and endpoint.get_data() != blank.get_data(),"Endpoint must visibly replace grenade with pulses")
			if direction == 2:
				await preload("res://tests/qa_capture.gd").capture(self,"grenade-%s-endpoint" % ("initial" if initial else "input"))
			for i in 10:
				state.tick([])
			var cleared := await snapshot(view)
			check(count_kind(state,"pulse") == 0,"Pulses expire after ten callback updates")
			check(cleared.get_data() == blank.get_data(),"Grenade and pulse visuals retire without remnants")
			if direction == 2:
				await preload("res://tests/qa_capture.gd").capture(self,"grenade-%s-cleared" % ("initial" if initial else "input"))
			view.free()
	if failed:
		quit(1)
		return
	print("GRENADE_RENDER_OK")
	quit()
