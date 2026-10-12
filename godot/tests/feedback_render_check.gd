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
	var state := GameState.new()
	var rows := PackedStringArray()
	for y in 13:
		rows.append("...............")
	state.setup(rows)
	var actor := state.heroes[0]
	actor.cell = Vector2i(8,7)
	actor.controller = HeroState.Controller.AI
	actor.lives = 2
	actor.shield = 0
	var view := GameView.new()
	view.state = state
	view.frozen = true
	root.add_child(view)
	var before := await snapshot()
	state.cell_at(actor.cell).energy = 1
	state.tick([])
	view.sync_view()
	var hit := await snapshot()
	check(actor.alive and actor.lives == 1, "fixture must survive one damaging hit")
	check(changed(before, hit, Rect2i(240,194,28,34)) > 20, "a surviving hit must visibly emit original smoke")
	actor.special_weapon = "rocket"
	actor.special_count = 2
	view.sync_view()
	var equipped := await snapshot()
	check(changed(hit, equipped, Rect2i(229,158,53,30)) > 80, "equipped weapon must be visible above the hero")
	await preload("res://tests/qa_capture.gd").capture(self, "feedback-equipped")
	view.free()
	# Force one rocket's very first active update to leave the right edge.
	# After the impact burst expires, its final smoke must still be visible.
	state.setup(rows)
	actor = state.heroes[0]
	actor.cell = Vector2i(14,6)
	actor.facing = 2
	var rocket := SpecialState.new("rocket", actor)
	rocket.position = Vector2(450,180)
	rocket.just_placed = false
	state.specials.append(rocket)
	state.register_callback(rocket)
	view = GameView.new()
	view.state = state
	view.frozen = true
	root.add_child(view)
	state.tick([])
	view.sync_view()
	for tick in 10:
		state.tick([])
		view.sync_view()
	var impact := await snapshot()
	for tick in 22:
		view.advance_presentation()
	var retired := await snapshot()
	check(changed(impact, retired, Rect2i(435,160,60,55)) > 5, "impact-tick rocket smoke must outlive the removed rocket and burst")
	view.free()
	# Original frame-2 setup attaches the human's nested, bobbing 1P pointer.
	state.setup(rows)
	state.generated = true
	actor = state.heroes[0]
	actor.cell = Vector2i(8,7)
	actor.shield = 0
	var second := state.heroes[1]
	second.controller = HeroState.Controller.HUMAN
	second.cell = Vector2i(11,7)
	second.shield = 0
	view = GameView.new()
	view.state = state
	view.frozen = true
	root.add_child(view)
	var pointer_start := await snapshot()
	for tick in 16:
		state.tick([])
		view.sync_view()
	var pointer_bob := await snapshot()
	check(changed(pointer_start, pointer_bob, Rect2i(240,140,30,33)) > 20, "human startup pointer must bob while the actor is idle")
	check(changed(pointer_start, pointer_bob, Rect2i(330,140,30,33)) > 20, "second human must have an independently colored 2P pointer")
	second.special_weapon = "rocket"
	second.special_count = 2
	view.sync_view()
	second.special_count = 0
	view.sync_view()
	var replaced_pointer := await snapshot()
	check(changed(pointer_bob, replaced_pointer, Rect2i(330,140,30,20)) > 20, "equipping must replace the startup pointer even after charges are exhausted")
	view.sync_view()
	check(changed(replaced_pointer, await snapshot(), Rect2i(330,140,30,20)) == 0, "repeated synchronization must not revive or advance the pointer")
	for tick in 133:
		state.tick([])
		view.sync_view()
	var pointer_last := await snapshot()
	state.tick([])
	view.sync_view()
	var pointer_gone := await snapshot()
	check(changed(pointer_last, pointer_gone, Rect2i(240,140,30,33)) > 20, "startup pointer must retire on update 150")
	view.free()
	# The original Symbol 299 count glyph ends at y=70 for this registration.
	# This catches Label/TextField baseline differences independently of the art.
	RenderingServer.set_default_clear_color(Color.WHITE)
	var blank := await snapshot()
	var indicator := WeaponIndicator.new()
	indicator.art = OriginalArt.new()
	indicator.position = Vector2(60,100)
	root.add_child(indicator)
	actor.special_weapon = "rocket"
	actor.special_count = 1
	indicator.sync(actor)
	var count_image := await snapshot()
	check(changed(blank, count_image, Rect2i(84,68,12,3)) > 0, "equipped count must use the source TextField baseline")
	actor.special_count = 10
	indicator.sync(actor)
	var ten := await snapshot()
	actor.special_count = 20
	indicator.sync(actor)
	check(changed(ten, await snapshot(), Rect2i(95,56,12,16)) == 0, "the second count digit must keep the source's tabular advance after either 1 or 2")
	indicator.free()
	if not failed:
		print("FEEDBACK_RENDER_OK")
	quit(1 if failed else 0)
