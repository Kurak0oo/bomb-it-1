class_name OriginalResults
extends Control
## Source 563 banner, 603 immediate score sheet, and 629 final score page.
## This presentation never awards points or advances GameSession itself.
signal action_requested(action: String)
signal scores_shown(terminal: bool)
const DIRECTORY := "res://art/original/results/"
const FONT = preload("res://art/original/fonts/295_Arial Black.ttf")
const OUTCOME_SECONDS := 5.5
const SKIP_SECONDS := 69.0 / 35.0 # Symbol 563 frame 70 installs key listener.
var session: GameSession
var phase := "outcome"
var elapsed := 0.0
var manifest: Dictionary
var banner: Sprite2D
var content: Control
var notice: Label
var names: Dictionary = {}
var saved_names: Dictionary = {}
var leaving := false

func _ready() -> void:
	size = Vector2(550,400)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	manifest = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	banner = _image("562-%d.png" % ({"win":2,"timeup_win":3,"lose":4,"timeup_lose":5}[session.result]),Vector2.ZERO)
	banner.visible = false
	_target(Rect2(0,0,550,400),confirm)

func advance(delta: float) -> void:
	if phase != "outcome":return
	elapsed += delta
	var frame := mini(int(elapsed * 35),69)
	var m: Variant = manifest.banner[frame]
	banner.visible = m != null
	if m != null:
		var b: Array = manifest.symbol562.bounds
		var source := Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))
		source.origin += SimRules.GAME_ORIGIN + Vector2(222.75,189.5)
		banner.transform = source.translated_local(Vector2(b[0],b[1])).scaled_local(Vector2.ONE/2)
	if elapsed >= OUTCOME_SECONDS:
		_show_scores()

func confirm() -> void:
	if leaving:return
	if phase == "outcome":
		if elapsed >= SKIP_SECONDS:_show_scores()
	elif phase == "scores":
		leaving = true
		action_requested.emit("continue")

func _show_scores() -> void:
	if phase != "outcome":return
	phase = "scores" if session.can_continue() else "final"
	scores_shown.emit(phase == "final")
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if phase == "scores":
		var layout: Dictionary = manifest["scores%d" % session.humans]
		_sheet(layout,Vector2(275,200))
		_fields(layout,Vector2(275,200))
		var b: Array = manifest.symbol579.bounds
		_image("579-%d.png" % (2 if session.result.ends_with("win") else 1),Vector2(278,362.35)+Vector2(b[0],b[1]))
	else:
		_image("final-background.png",Vector2.ZERO)
		var layout: Dictionary = manifest["final%d" % session.humans]
		var b: Array = layout.bounds
		_sheet(layout,Vector2(275,209.2))
		_fields(layout,Vector2(275,209.2))
		b = manifest.symbol611.bounds
		_image("611-%d.png" % (session.difficulty+2 if session.result.ends_with("win") and session.stage == session.total_stages else 1),Vector2(275,38.6)+Vector2(b[0],b[1]))
		notice = _text("Scores are saved locally",Rect2(100,301,350,20),12)
		for entry in [["PLAY AGAIN",Rect2(135,365,140,28),"replay"],["MAIN MENU",Rect2(285,365,140,28),"menu"]]:
			var button := Button.new()
			button.text = entry[0]
			button.position = entry[1].position
			button.size = entry[1].size
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size",14)
			for style_name in ["normal","hover","pressed"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color("f34c9c") if style_name == "normal" else Color("d92c7c")
				style.border_color = Color.WHITE
				style.set_border_width_all(2)
				style.set_corner_radius_all(6)
				button.add_theme_stylebox_override(style_name,style)
			button.pressed.connect(func():
				if not leaving:
					leaving = true
					action_requested.emit(entry[2]))
			content.add_child(button)

func _sheet(layout: Dictionary, origin: Vector2) -> void:
	var bounds: Array = layout.bounds
	for layer in layout.layers:
		if layer.kind == "static":
			_image(layer.image,origin+Vector2(bounds[0],bounds[1]))
			continue
		var m: Array = layer.matrix
		var b: Array = layer.bounds
		var placement := Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),origin+Vector2(m[4],m[5]))
		var rectangle := placement * Rect2(b[0],b[1],b[2],b[3])
		var callback := confirm if int(layer.symbol) == 566 else func():
			if int(layer.symbol) == 614:action_requested.emit("save")
			else:notice.text = "Original portal unavailable"
		var button := _target(rectangle,callback)
		for state in [["normal",0],["hover",1],["pressed",2],["hover_pressed",2]]:
			var style := StyleBoxTexture.new()
			style.texture = load(DIRECTORY+"button-%d-%d.png" % [int(layer.symbol),state[1]])
			button.add_theme_stylebox_override(state[0],style)

func _fields(layout: Dictionary, origin: Vector2) -> void:
	for field in layout.fields:
		var rect := Rect2(origin+Vector2(field.rect[0],field.rect[1]),Vector2(field.rect[2],field.rect[3]))
		if field.name.begins_with("_parent.playerName"):
			var input := LineEdit.new()
			input.position = rect.position
			input.size = rect.size
			var player_id := int(str(field.name).right(1))-1
			input.placeholder_text = "Player %d" % (player_id+1)
			input.text = saved_names.get(player_id,"")
			input.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			input.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
			input.max_length = 20
			content.add_child(input)
			names[player_id] = input
			continue
		var id := int(str(field.name).right(1))-1
		var hero := session.state.heroes[id]
		var values := {"killScore":hero.kill_score,"destruction":hero.destruction_score,"timeScore":hero.time_score,"bonus":hero.bonus_score,"score":hero.score,"totalScore":session.totals[id]}
		var key := str(field.name).left(-1)
		var label := _text(str(values[key]),rect,20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if field.align == 0 else HORIZONTAL_ALIGNMENT_CENTER

func _image(file: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(DIRECTORY+file)
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2.ONE/2
	content.add_child(sprite)
	return sprite

func _text(value: String, rectangle: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rectangle.position
	label.size = rectangle.size
	label.text = value
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return label

func _target(rectangle: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = rectangle.position
	button.size = rectangle.size
	button.focus_mode = Control.FOCUS_NONE
	for style in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	button.pressed.connect(callback)
	content.add_child(button)
	return button
