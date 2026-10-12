extends Node2D

var art: OriginalArt
var session := GameSession.new()
var audio: GameAudio
var world: Node2D
var ui: Control
var overlay: Control
var view: GameView
var touch: MobileInput
var original_hud: OriginalHud
var original_results: OriginalResults
var screen := "menu"
var paused := false
var difficulty := 1
var selected_character := 1
var selected_second_character := 2
var players := 1
var high_score := 0
var touch_enabled := false
var prefs := ConfigFile.new()
var fire_inputs: Array[FireInput] = [FireInput.new(), FireInput.new()]
var save_enabled := true
var keyboard := KeyboardInput.new()
var original_menu: OriginalMenu
# Optional platform adapter returning a physical display-space safe rectangle.
var safe_area_provider := Callable()
var _last_safe_area := Rect2()

func _ready() -> void:
	art = OriginalArt.new()
	if save_enabled:
		prefs.load("user://preferences.cfg")
	high_score = prefs.get_value("game", "high_score", 0)
	audio = GameAudio.new()
	add_child(audio)
	audio.muted = prefs.get_value("game", "muted", false)
	touch_enabled = OS.get_name() in ["Android", "iOS"]
	for binding in [["p1_left",KEY_A], ["p1_up",KEY_W], ["p1_right",KEY_D], ["p1_down",KEY_S], ["p1_bomb",KEY_SPACE], ["p2_left",KEY_LEFT], ["p2_up",KEY_UP], ["p2_right",KEY_RIGHT], ["p2_down",KEY_DOWN], ["p2_bomb",KEY_ENTER]]:
		_bind_key(binding[0], binding[1])
	get_viewport().size_changed.connect(_resize)
	_resize()
	_show_menu()

func _resize() -> void:
	if not is_inside_tree():return
	_reset_input()
	var safe := _safe_viewport_rect()
	_last_safe_area = safe
	var area := safe
	var active := is_instance_valid(touch) and touch.is_inside_tree() and touch.is_visible_in_tree()
	if active:
		# Reserve complete hit circles, including a five-pixel gap to the game.
		# Prefer whichever arrangement preserves the larger 550x400 surface.
		var side_scale := minf(safe.size.y/400.0,(safe.size.x-280.0)/550.0)
		var dock_scale := minf((safe.size.y-140.0)/400.0,safe.size.x/550.0)
		if side_scale >= dock_scale:
			area = Rect2(safe.position+Vector2(140,0),safe.size-Vector2(280,0))
		else:
			area.size.y -= 140
		var y := safe.end.y-70
		touch.configure(Vector2(safe.position.x+70,y),Vector2(safe.end.x-70,y))
	var factor := minf(1.0,minf(area.size.x/550.0,area.size.y/400.0))
	scale = Vector2.ONE * factor
	position = area.position+(area.size-Vector2(550,400)*factor)/2

func _safe_viewport_rect() -> Rect2:
	var viewport := get_viewport_rect()
	var physical: Rect2
	if safe_area_provider.is_valid():
		physical = safe_area_provider.call()
	elif OS.get_name() in ["Android","iOS"]:
		physical = Rect2(DisplayServer.get_display_safe_area())
	else:
		# Desktop usable-screen bounds include taskbars and are not phone insets.
		return viewport
	if not physical.has_area():return viewport
	# Viewport screen coordinates are relative to the containing native window.
	physical.position -= Vector2(get_window().position)
	var safe := (get_viewport().get_screen_transform().affine_inverse() * physical).intersection(viewport)
	return safe if safe.has_area() else viewport

func _clear_screen() -> void:
	_reset_input()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	if is_instance_valid(ui):
		remove_child(ui)
		ui.queue_free()
	world = Node2D.new()
	add_child(world)
	ui = Control.new()
	ui.z_index = 3000
	add_child(ui)
	view = null
	original_menu = null
	touch = null
	overlay = null
	original_hud = null
	original_results = null
	paused = false
	_resize()

func _background(path: String) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.centered = false
	sprite.z_index = -200
	world.add_child(sprite)

func _show_menu() -> void:
	_show_original_menu("menu")
	audio.play_music("406_Bombit_-_mainscreen.mp3")

func _show_original_menu(page: String) -> void:
	_clear_screen()
	screen = page
	original_menu = OriginalMenu.new()
	original_menu.page = page
	original_menu.muted = audio.muted
	original_menu.touch_help = touch_enabled
	original_menu.action_requested.connect(_menu_action)
	ui.add_child(original_menu)

func _menu_action(action: String) -> void:
	match action:
		"players": _show_players()
		"one", "two":
			players = 1 if action == "one" else 2
			selected_character = 1
			selected_second_character = 2
			_show_original_menu("difficulty")
		"easy", "normal", "hard":
			difficulty = ["easy", "normal", "hard"].find(action)
			_show_select()
		"help": _show_help()
		"powerups": _show_original_menu("powerups")
		"back":
			if screen == "select": _show_original_menu("difficulty")
			elif screen == "difficulty": _show_players()
			else: _show_menu()
		"start": _start_game()
		"sound": _toggle_sound()
		"best": original_menu.show_notice("LOCAL BEST  %06d" % high_score)
		"portal": original_menu.show_notice("Original portal link unavailable")

func _show_players() -> void:
	_show_original_menu("players")

func _show_select() -> void:
	_clear_screen()
	screen = "select"
	var selection := OriginalSelection.new()
	selection.players = players
	selection.choices = [selected_character, selected_second_character]
	selection.muted = audio.muted
	selection.choices_changed.connect(func(first: int, second: int): selected_character = first; selected_second_character = second)
	selection.action_requested.connect(_menu_action)
	original_menu = selection
	ui.add_child(selection)

func _show_help() -> void:
	_show_original_menu("help")

func _start_game() -> void:
	session.start(int(Time.get_unix_time_from_system()), difficulty, selected_character, players, selected_second_character)
	_show_round()

func _show_round() -> void:
	_clear_screen()
	screen = "game"
	_background("res://art/backdrop.png")
	view = GameView.new()
	view.art = art
	view.state = session.state
	view.position = SimRules.GAME_ORIGIN
	world.add_child(view)
	original_hud = OriginalHud.new()
	original_hud.art = art
	# The HUD backdrop is behind the arena; counters remain in its left gutter.
	world.add_child(original_hud)
	world.move_child(original_hud, 1)
	_button(ui, "SND", Rect2(4,363,39,17), _toggle_sound)
	_button(ui, "Ⅱ", Rect2(46,363,36,17), _toggle_pause)
	_button(ui, "TOUCH", Rect2(4,382,78,15), _toggle_touch)
	touch = MobileInput.new()
	touch.set_as_top_level(true)
	touch.z_index = 3000
	touch.fire_changed.connect(func(held: bool): fire_inputs[0].set_source("touch", held))
	touch.input_cancelled.connect(_reset_input)
	touch.visible = touch_enabled
	ui.add_child(touch)
	touch.visibility_changed.connect(_resize)
	_resize()
	_update_hud()
	audio.play_music(["401_Bombit_-_level_1.mp3","402_Bombit_-_level_2.mp3","403_Bombit_-_level_3.mp3","404_Bombit_-_level_4.mp3"][(session.stage-1)%4])

func _command(id: int) -> PlayerCommands:
	var command := keyboard.poll(id, players)
	fire_inputs[id].set_source("keyboard", command.bomb_requested)
	if id == 0 and touch_enabled:
		if touch.direction != Vector2i.ZERO:
			command.direction = touch.direction
	var fire := fire_inputs[id].poll()
	fire.direction = command.direction
	return fire

func _input(event: InputEvent) -> void:
	keyboard.observe(event)
	if screen != "game" or paused:
		return
	for id in players:
		var action := "p%d_bomb" % (id + 1)
		if event.is_action_pressed(action):
			fire_inputs[id].set_source("keyboard", true)
		elif event.is_action_released(action):
			fire_inputs[id].set_source("keyboard", false)

func _reset_input() -> void:
	keyboard.cancel()
	if is_instance_valid(touch):
		touch.release_all()
	for id in 2:
		fire_inputs[id].set_source("keyboard", Input.is_action_pressed("p%d_bomb" % (id + 1)))
		fire_inputs[id].cancel()

func _physics_process(_delta: float) -> void:
	if screen == "result":
		view.advance_presentation()
		return
	if screen != "game" or paused:
		return
	view.capture_positions()
	var commands: Array[PlayerCommands] = [_command(0)]
	if players == 2:
		commands.append(_command(1))
	session.tick(commands)
	view.sync_view()
	audio.events(session.state.events)
	_update_hud()
	if session.result != "":
		_show_result()

func _update_hud() -> void:
	original_hud.sync(session)

func _show_result() -> void:
	if screen == "result":
		return
	screen = "result"
	view.frozen = true
	if session.result == "timeup_lose":
		view.present_timeout_loss()
	_reset_input()
	touch.enabled = false
	var win := session.result.ends_with("win")
	audio.play_music("405_Bombit_-_level_complete.mp3" if win else "407_Bombit_-_mission_failed.mp3", false)
	for id in players:
		high_score = maxi(high_score, session.totals[id])
	_save_preferences()
	original_results = OriginalResults.new()
	original_results.session = session
	original_results.saved_names = {0:prefs.get_value("game","player_name1",""),1:prefs.get_value("game","player_name2","")}
	original_results.scores_shown.connect(func(terminal: bool):
		if terminal:
			audio.play_music("406_Bombit_-_mainscreen.mp3")
		else:
			audio.music.stop())
	original_results.action_requested.connect(_result_action)
	ui.add_child(original_results)

func _process(delta: float) -> void:
	if _safe_viewport_rect() != _last_safe_area:
		_resize()
	if screen == "result" and is_instance_valid(original_results):
		original_results.advance(delta)

func _result_action(action: String) -> void:
	if screen != "result":
		return
	match action:
		"continue":
			if original_results.phase == "scores" and session.can_continue():
				session.next_round()
				_show_round()
		"replay": _start_game()
		"menu": _show_menu()
		"save":
			for id in original_results.names:
				prefs.set_value("game","player_name%d" % (id+1),original_results.names[id].text)
			_save_preferences()
			original_results.notice.text = "Saved locally · best %d" % high_score

func _toggle_pause() -> void:
	if screen != "game":
		return
	paused = not paused
	view.frozen = paused
	audio.music.stream_paused = paused
	_reset_input()
	touch.enabled = not paused
	if not paused:
		if is_instance_valid(overlay):
			ui.remove_child(overlay)
			overlay.queue_free()
			overlay = null
		return
	overlay = Control.new()
	ui.add_child(overlay)
	_panel(overlay, Rect2(164,122,273,167))
	_label(overlay, "PAUSED", Rect2(175,137,250,40), 28)
	_button(overlay, "RESUME", Rect2(203,190,193,34), _toggle_pause)
	_button(overlay, "MAIN MENU", Rect2(203,238,193,29), _show_menu)

func _toggle_sound() -> void:
	audio.muted = not audio.muted
	_save_preferences()
	if is_instance_valid(original_menu):
		original_menu.set_muted(audio.muted)

func _toggle_touch() -> void:
	touch_enabled = not touch_enabled
	_reset_input()
	touch.visible = touch_enabled

func _save_preferences() -> void:
	if not save_enabled:
		return
	prefs.set_value("game", "high_score", high_score)
	prefs.set_value("game", "muted", audio.muted)
	prefs.save("user://preferences.cfg")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and screen == "game" and not paused:
		_toggle_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if screen == "result" and event is InputEventKey:
		if not event.pressed:
			original_results.confirm()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			if screen == "game":
				_toggle_pause()
			elif event.keycode == KEY_ESCAPE and screen != "menu":
				_show_menu()
		elif event.keycode == KEY_M:
			_toggle_sound()

func _bind_key(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action, event)

func _panel(parent: Node, rectangle: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rectangle.position
	panel.size = rectangle.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff0fa")
	style.border_color = Color("f36ba7")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Node, value: String, rectangle: Rect2, font_size: int, color: Color = Color("9a2464")) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rectangle.position
	label.size = rectangle.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 0)
	label.size = rectangle.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, rectangle: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rectangle.position
	button.size = rectangle.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14 if rectangle.size.y >= 25 else 9)
	for style_name in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f34c9c") if style_name == "normal" else Color("d92c7c")
		style.border_color = Color.WHITE
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		style.content_margin_left = 2
		style.content_margin_right = 2
		button.add_theme_stylebox_override(style_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	# Set requested size after theme overrides; the default theme's minimum
	# otherwise leaves small HUD buttons taller than their allotted space.
	button.size = rectangle.size
	button.pressed.connect(callback)
	parent.add_child(button)
	button.set_deferred("size", rectangle.size)
	return button
