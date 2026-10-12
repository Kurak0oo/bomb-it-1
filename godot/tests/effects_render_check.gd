extends SceneTree
## Independent original playback repeats pickup frame two at ages 1 and 80.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(550,400)
	RenderingServer.set_default_clear_color(Color.WHITE)
	var state := GameState.new()
	var rows := PackedStringArray()
	for y in 13:
		rows.append("...............")
	state.setup(rows)
	for actor in state.heroes:
		actor.alive = false
		actor.death_ticks = 36
	for i in 6:
		state.cell_at(Vector2i(2+i*2,7)).item = ["life","glove","bomb","shield","power","shoe"][i]
	var view := GameView.new()
	view.state = state
	view.frozen = true
	root.add_child(view)
	for child in view.get_children():
		if child is Sprite2D:
			child.visible = false
	state.tick([])
	view.sync_view()
	await process_frame
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	for age in range(2,81):
		state.tick([])
		view.sync_view()
	await process_frame
	await RenderingServer.frame_post_draw
	var repeated := root.get_texture().get_image()
	var passed := first.get_data() == repeated.get_data()
	if not passed:
		push_error("All six pickup icons and shadows must repeat after 79 source display updates")
	await preload("res://tests/qa_capture.gd").capture(self,"ordinary-pickup-loop")
	for age in range(81,87):
		state.tick([])
	for i in 6:
		state.cell_at(Vector2i(2+i*2,7)).item = ""
	view.sync_view()
	for age in 9:
		state.tick([])
		view.sync_view()
	await process_frame
	await RenderingServer.frame_post_draw
	# Original life pickup's white cross fades per fill over its cyan body.
	var life_fade := root.get_texture().get_image().get_pixel(76,180)
	if [life_fade.r8,life_fade.g8,life_fade.b8] != [199,237,246]:
		passed = false
		push_error("Pickup fills must fade before overlap compositing: " + str(life_fade))
	await preload("res://tests/qa_capture.gd").capture(self,"ordinary-pickup-fade")
	view.free()
	state = GameState.new()
	state.setup(rows)
	for actor in state.heroes:
		actor.alive = false
		actor.death_ticks = 36
	var actor := state.heroes[0]
	actor.cell = Vector2i(8,6)
	actor.character_id = 1
	actor.bomb_level = 3
	actor.shield = 999
	view = GameView.new()
	view.state = state
	view.frozen = true
	root.add_child(view)
	for child in view.get_children():
		child.visible = false
	actor.alive = true
	var command := PlayerCommands.new()
	command.request_bomb()
	state.tick([command])
	state.bombs[0].fuse = 1
	state.tick([])
	for tick in 17:
		state.tick([])
	view.sync_view()
	for hero in view._hero_sprites.values():
		hero.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	# Literal original-runtime interior pixel at flame1 tick16, retained capture.
	var faded := root.get_texture().get_image().get_pixel(247,187)
	if [faded.r8,faded.g8,faded.b8] != [252,219,234]:
		passed = false
		push_error("Source flame fade pixel must be (252,219,234): " + str(faded))
	await preload("res://tests/qa_capture.gd").capture(self,"ordinary-flame-fade")
	view.free()
	if passed:
		print("EFFECTS_RENDER_OK")
	quit(0 if passed else 1)
