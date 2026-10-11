extends SceneTree

var failed := false
var main: Node2D

func _init() -> void:
	call_deferred("run")

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_physics_process(false)
	main.audio.muted = true
	await capture("menu")
	for control in main.ui.get_children():
		if control is Button and control.text == "1 PLAYER":
			control.pressed.emit()
			break
	check(main.screen == "select", "menu signal safely changes screens")
	await capture("select")
	main.session.start(42, 1, 1, 1)
	main._show_round()
	main.set_physics_process(false)
	await capture("arena")
	for control in main.ui.get_children():
		if control is Button:
			check(control.position.y + control.size.y <= 400, "HUD buttons fit inside the game area")
			if control.text in ["SND", "Ⅱ"]:
				check(control.position.y + control.size.y <= 382, "HUD controls do not overlap touch toggle")
	Input.action_press("p1_right")
	for i in 7:
		main._physics_process(1.0/35)
	Input.action_release("p1_right")
	check(main.session.state.heroes[0].cell == Vector2i(4,3), "keyboard moves hero through main loop")
	Input.action_press("p1_bomb")
	main._physics_process(1.0/35)
	Input.action_release("p1_bomb")
	check(main.session.state.bombs.size() > 0, "keyboard places bomb through main loop")
	main._toggle_pause()
	var tick: int = main.session.state.tick_number
	main._physics_process(1.0/35)
	check(main.session.state.tick_number == tick, "pause freezes simulation")
	await capture("pause")
	main._toggle_pause()
	for i in 20:
		main._physics_process(1.0/35)
	check(main.session.state.tick_number > tick, "resume advances simulation")
	main.session.state.heroes[1].alive = false
	main.session.state.heroes[2].alive = false
	main.session.state.heroes[3].alive = false
	main._physics_process(1.0/35)
	check(main.screen == "result", "winning round displays result")
	await capture("result")
	tick = main.session.state.tick_number
	for i in 36:
		main._physics_process(1.0/35)
	check(main.session.state.tick_number == tick, "result animation leaves simulation stopped")
	check(not main.view._hero_sprites[1].visible, "death finishes behind result overlay")
	main.session.next_round()
	main._show_round()
	check(main.session.stage == 2, "next stage rebuilds view")
	root.size = Vector2i(1600,800)
	await process_frame
	main.touch_enabled = true
	main.touch.visible = true
	main.touch.queue_redraw()
	await capture("touch")
	var finger := InputEventScreenTouch.new()
	finger.index = 0
	finger.pressed = true
	finger.position = main.touch.global_position + main.touch._stick + Vector2(32,0)
	main.touch._input(finger)
	check(main.touch.direction == Vector2i.RIGHT, "touch stick resolves cardinal direction")
	finger.index = 1
	finger.position = main.touch.global_position + main.touch._bomb
	main.touch._input(finger)
	check(main.touch.bomb_held and main.touch.direction == Vector2i.RIGHT, "multitouch movement and bomb coexist")
	main.touch.release_all()
	check(not main.touch.bomb_held and main.touch.direction == Vector2i.ZERO, "touch resets on pause")
	main._show_help()
	await capture("help")
	main.players = 2
	main.selection_slot = 0
	main._show_select()
	main._choose_character(3)
	main._start_game()
	check(main.screen == "select" and main.selection_slot == 1, "two-player setup selects second robot")
	main._choose_character(4)
	main._start_game()
	check(main.session.state.heroes[0].character_id == 3 and main.session.state.heroes[1].character_id == 4, "both selected characters enter game")
	main.set_physics_process(false)
	main.free()
	# Give the audio mixing thread time to release the last playback resource.
	await create_timer(0.15).timeout
	if not failed:
		print("UI_OK")
	quit(1 if failed else 0)

func capture(name_text: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(ProjectSettings.globalize_path("res://../reference/qa-" + name_text + ".png"))

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		print("FAIL: " + message)
