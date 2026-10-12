extends SceneTree
## Source finite clips keep their own display age after parent/outcome changes.

var failed := false

func _init() -> void:
	call_deferred("run")

func make_view() -> GameView:
	var state := GameState.new()
	var rows := PackedStringArray()
	for y in 13: rows.append("...............")
	state.setup(rows)
	for actor in state.heroes:
		actor.alive = false
		actor.death_ticks = 36
	var view := GameView.new()
	view.state = state
	view.frozen = true
	root.add_child(view)
	for child in view.get_children(): child.visible = false
	return view

func pixels() -> PackedByteArray:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_data()

func place(view: GameView, kind: String) -> SpecialState:
	var actor := view.state.heroes[0]
	actor.cell = Vector2i(8,6)
	actor.facing = 2
	actor.special_weapon = kind
	actor.special_count = 1
	actor.fire_ready = true
	check(SpecialRules.place(view.state,actor),"Fixture weapon placement succeeds")
	var weapon: SpecialState = view.state.specials.back()
	weapon.just_placed = false # Installed before the first observed callback.
	view.sync_view()
	return weapon

func run() -> void:
	root.size = Vector2i(550,400)
	RenderingServer.set_default_clear_color(Color.WHITE)
	var blank := await pixels()
	for kind in ["fire","ice"]:
		var view := make_view()
		place(view,kind)
		for tick in 49:
			view.state.tick([])
			view.sync_view()
		check(view.state.specials.is_empty(),kind+" controller has finished at update49")
		check(await pixels()!=blank,kind+" last child remains visible after its controller retires")
		await preload("res://tests/qa_capture.gd").capture(self,"special-"+kind+"-parent-retired")
		for tick in 2:
			view.state.tick([])
			view.sync_view()
		check(await pixels()==blank,kind+" child removes on its source frame40")
		view.free()
	for round_number in 3:
		var view := make_view()
		var weapon := place(view,"ice" if round_number==1 else "fire")
		for tick in 12:
			view.state.tick([])
			view.sync_view()
		SpecialRules.pulse(view.state,Vector2i(3,6),0)
		view.state.pops.append(GameState.Pop.new(Vector2i(4,6)))
		view.sync_view()
		check(await pixels()!=blank,"Finite effects are visible before outcome")
		var tick_before := view.state.tick_number
		var age_before := weapon.age
		var energy_before := view.state.cell_at(Vector2i(3,6)).energy
		for tick in 39: view.advance_presentation()
		check(await pixels()==blank,"Outcome completes finite effects without simulation callbacks")
		check(view.state.tick_number==tick_before and weapon.age==age_before and view.state.cell_at(Vector2i(3,6)).energy==energy_before,"Presentation leaves authoritative tick, weapon age and energy unchanged")
		if round_number==0:
			await preload("res://tests/qa_capture.gd").capture(self,"special-outcome-finished")
		view.free()
		check(await pixels()==blank,"Round teardown releases every transient")
	var view := make_view()
	view.state.cell_at(Vector2i(9,6)).kind = GameState.Kind.BRICK
	place(view,"rocket")
	for tick in 5:
		view.state.tick([])
		view.sync_view()
	check(view._trails.size()==5,"Impact retains the fifth smoke emitted before source collision")
	check(not view._trails.is_empty() and view._trails.back().node.position==Vector2(255,180),"Final impact smoke uses the actual collision position")
	view.sync_view()
	check(view._trails.size()==5,"Repeated display sync cannot duplicate impact smoke")
	await preload("res://tests/qa_capture.gd").capture(self,"special-rocket-impact")
	var tick_before := view.state.tick_number
	for tick in 21: view.advance_presentation()
	check(view._trails.is_empty(),"All independently born smoke clips retire on source frame22")
	check(await pixels()==blank,"Impact burst and all smoke finish after outcome")
	check(view.state.tick_number==tick_before,"Smoke completion does not advance gameplay")
	view.free()
	view = make_view()
	var grenade := place(view,"grenade")
	grenade.direction = Vector2i.DOWN
	grenade.cell = grenade.origin+Vector2i(0,2)
	for tick in 7:
		view.state.tick([])
		view.sync_view()
	# Independent #31 source trace: frame8 depth965, frame9 depth1265.
	check(view._special_sprites[grenade].z_index==965,"Grenade frame8 remains at origin depth")
	view.state.tick([])
	view.sync_view()
	check(view._special_sprites[grenade].z_index==1265,"Grenade frame9 swaps to target depth")
	await preload("res://tests/qa_capture.gd").capture(self,"special-grenade-depth")
	view.free()
	for kind in ["mine","gas"]:
		view = make_view()
		var weapon := place(view,kind)
		for tick in (59 if kind=="mine" else 100): view.advance_presentation()
		check(await pixels()==blank,kind+" timeline reaches its invisible source stop frame after outcome")
		check(weapon.age==0 and view.state.tick_number==0,"Mine/gas playback does not consume gameplay callbacks")
		view.free()
	for kind in ["rocket","grenade"]:
		view = make_view()
		var weapon := place(view,kind)
		var first := await pixels()
		for tick in 2: view.advance_presentation()
		check(await pixels()!=first,kind+" nested timeline continues after outcome")
		for tick in (6 if kind=="rocket" else 17): view.advance_presentation()
		check(await pixels()==first,kind+" preserves its source nested loop")
		check(weapon.age==0 and view.state.tick_number==0 and view._trails.is_empty(),"Nested playback cannot move, collide or emit new smoke")
		view.free()
	if not failed: print("SPECIAL_EFFECTS_RENDER_OK")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
