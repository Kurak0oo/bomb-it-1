extends Node2D

var art: OriginalArt
var session := GameSession.new()
var audio: GameAudio
var world: Node2D
var ui: Control
var overlay: Control
var view: GameView
var touch: MobileInput
var hud: Array[Label] = []
var hud_scores: Array[Label] = []
var timer_label: Label
var stage_label: Label
var screen := "menu"
var paused := false
var difficulty := 1
var selected_character := 1
var selected_second_character := 2
var selection_slot := 0
var players := 1
var high_score := 0
var touch_enabled := false
var prefs := ConfigFile.new()
var fire_inputs: Array[FireInput] = [FireInput.new(), FireInput.new()]
var save_enabled := true
var keyboard := KeyboardInput.new()

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
	position = (get_viewport_rect().size - Vector2(550,400)) / 2
	if is_instance_valid(touch):
		touch.queue_redraw()

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
	touch = null
	overlay = null
	hud.clear()
	hud_scores.clear()
	paused = false

func _background(path: String) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.centered = false
	sprite.z_index = -200
	world.add_child(sprite)

func _show_menu() -> void:
	_clear_screen()
	screen = "menu"
	_background("res://art/original/menu.png")
	# Buttons occupy the positions of the original menu artwork.
	_button(ui, "1 PLAYER", Rect2(411,141,112,31), func(): players = 1; selection_slot = 0; _show_select())
	_button(ui, "2 PLAYERS", Rect2(410,215,113,31), func(): players = 2; selection_slot = 0; _show_select())
	_button(ui, "HOW TO PLAY", Rect2(361,270,161,31), _show_help)
	_button(ui, "SOUND OFF" if audio.muted else "SOUND ON", Rect2(104,378,84,20), _toggle_sound)
	_label(ui, "BEST  %06d" % high_score, Rect2(365,315,164,23), 15, Color("75255f"))
	audio.play_music("406_Bombit_-_mainscreen.mp3")

func _show_select() -> void:
	_clear_screen()
	screen = "select"
	_background("res://art/original/menu.png")
	_panel(ui, Rect2(62,65,426,300))
	_label(ui, "CHOOSE YOUR ROBOT" if players == 1 else "PLAYER %d · CHOOSE ROBOT" % (selection_slot + 1), Rect2(80,78,390,35), 23)
	for id in 4:
		var x := 100 + id * 92
		var preview := art.sprite([90,68,46,24][id], 4)
		preview.position += Vector2(x + 14,161)
		preview.scale = Vector2(1.5,1.5)
		ui.add_child(preview)
		var choice := selected_character if selection_slot == 0 else selected_second_character
		var choose := _button(ui, "P%d" % (selection_slot + 1) if choice == id + 1 else str(id + 1), Rect2(x-7,199,65,28), func(): _choose_character(id + 1))
		choose.disabled = selection_slot == 1 and id + 1 == selected_character
	for level in 3:
		var names := ["EASY", "NORMAL", "HARD"]
		_button(ui, ("• " if difficulty == level else "") + names[level], Rect2(102+level*115,244,106,28), func(): difficulty = level; _show_select())
	_button(ui, "BACK", Rect2(98,306,110,34), _show_menu)
	_button(ui, "PLAYER 2 →" if players == 2 and selection_slot == 0 else "LET'S PLAY", Rect2(232,302,219,40), _start_game)

func _choose_character(id: int) -> void:
	if selection_slot == 0:
		selected_character = id
		if selected_second_character == id:
			selected_second_character = id % 4 + 1
	else:
		selected_second_character = id
	_show_select()

func _show_help() -> void:
	_show_select()
	screen = "help"
	for child in ui.get_children():
		child.queue_free()
	_panel(ui, Rect2(48,35,454,330))
	_label(ui, "HOW TO PLAY", Rect2(67,48,416,37), 26)
	_label(ui, "Drop bombs, then get clear. Defeat the other robots!\nBreak scenery to uncover upgrades and special weapons.\n\n1P: Arrow keys or WASD · Space to bomb\n2P: P1 WASD + Space · P2 Arrows + Enter\nEsc / P pauses · M toggles sound\n\nTouch: left stick to move · right button to bomb\nRelease the Bomb button between special-weapon shots.", Rect2(69,100,415,190), 13)
	_button(ui, "GOT IT", Rect2(170,309,210,34), _show_menu)

func _start_game() -> void:
	if screen == "select" and players == 2 and selection_slot == 0:
		selection_slot = 1
		_show_select()
		return
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
	for id in 4:
		var y := 7 + id * 68
		var panel := _panel(ui, Rect2(7,y,72,65))
		panel.modulate = Color("ffd5eb")
		var portrait := art.sprite([90,68,46,24][session.state.heroes[id].character_id - 1], 4)
		portrait.position = Vector2(12,y+27) + art.offset([90,68,46,24][session.state.heroes[id].character_id - 1]) * 0.7
		portrait.scale = Vector2(0.7,0.7)
		ui.add_child(portrait)
		var label := _label(ui, "", Rect2(37,y+2,39,43), 9, Color("572047"))
		label.add_theme_constant_override("line_spacing", -4)
		hud.append(label)
		hud_scores.append(_label(ui, "", Rect2(9,y+44,68,18), 11, Color("9a2464")))
	_panel(ui, Rect2(4,299,78,59))
	stage_label = _label(ui, "", Rect2(7,304,72,18), 11)
	timer_label = _label(ui, "", Rect2(7,326,72,25), 19)
	_button(ui, "SND", Rect2(4,363,39,17), _toggle_sound)
	_button(ui, "Ⅱ", Rect2(46,363,36,17), _toggle_pause)
	_button(ui, "TOUCH", Rect2(4,382,78,15), _toggle_touch)
	touch = MobileInput.new()
	touch.fire_changed.connect(func(held: bool): fire_inputs[0].set_source("touch", held))
	touch.input_cancelled.connect(_reset_input)
	touch.visible = touch_enabled
	ui.add_child(touch)
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
	for id in 4:
		var hero := session.state.heroes[id]
		var name_text := "P%d" % (id+1) if id < players else "CPU %d" % id
		var effect := "%s %d" % [hero.special_weapon.left(3).to_upper(), hero.special_count] if hero.special_count > 0 else "SHIELD" if hero.armor else "FIRE %d" % hero.bomb_level
		hud[id].text = "%s%s\nLIFE %d\nBOMB %d\n%s" % [name_text, "" if hero.alive else " ×", maxi(hero.lives,0), hero.bombs_available, effect]
		hud_scores[id].text = "%06d" % (session.totals[id]+(hero.score if session.result == "" else 0))
	stage_label.text = "LEVEL %02d" % session.stage
	var seconds := ceili(session.remaining_ticks / 35.0)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]

func _show_result() -> void:
	screen = "result"
	view.frozen = true
	_reset_input()
	touch.enabled = false
	var win := session.result.ends_with("win")
	audio.play_music("405_Bombit_-_level_complete.mp3" if win else "407_Bombit_-_mission_failed.mp3", false)
	for id in players:
		high_score = maxi(high_score, session.totals[id])
	_save_preferences()
	overlay = Control.new()
	ui.add_child(overlay)
	_panel(overlay, Rect2(127,95,352,229))
	var title := "STAGE CLEAR!" if win else "TRY AGAIN!" if session.can_continue() else "GAME OVER"
	if win and session.stage == session.total_stages:
		title = "YOU WIN!"
	if session.result.begins_with("timeup"):
		title = "TIME UP · " + ("YOU WIN" if win else "ROUND LOST")
	_label(overlay, title, Rect2(135,110,336,34), 23)
	var score_text := "SCORE  %06d\nBEST  %06d" % [session.totals[0],high_score] if players == 1 else "P1  %06d   P2  %06d\nBEST  %06d" % [session.totals[0],session.totals[1],high_score]
	_label(overlay, score_text, Rect2(144,160,318,55), 17)
	if session.can_continue():
		_button(overlay, "NEXT STAGE" if win else "RETRY", Rect2(163,226,278,35), func(): session.next_round(); _show_round())
	else:
		_button(overlay, "PLAY AGAIN", Rect2(163,226,278,35), _start_game)
	_button(overlay, "MAIN MENU", Rect2(192,275,220,28), _show_menu)

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
	if screen == "menu":
		_show_menu()

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			if screen == "game":
				_toggle_pause()
			elif event.keycode == KEY_ESCAPE and screen != "menu":
				_show_menu()
		elif event.keycode == KEY_M:
			_toggle_sound()
		elif event.keycode == KEY_ENTER:
			if screen == "menu":
				selection_slot = 0
				_show_select()
			elif screen == "select":
				_start_game()
			elif screen == "result":
				if session.can_continue():
					session.next_round()
					_show_round()
				else:
					_start_game()

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
