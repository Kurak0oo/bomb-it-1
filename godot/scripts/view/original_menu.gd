class_name OriginalMenu
extends Control
## Original root display lists, split around interactive button placements.
## Navigation happens on release; a new screen cannot inherit an old press.

signal action_requested(action: String)

enum PressOwner { NONE, KEYBOARD, MOUSE, TOUCH }

const DIRECTORY := "res://art/original/menus/"
const ACTIONS := {439: "players", 440: "help", 441: "best", 442: "portal", 443: "portal", 462: "one", 463: "two", 473: "powerups", 460: "sound"}
var page := "menu"
var muted := false
var touch_help := false
var buttons: Array[Dictionary] = []
var focus := 0
var hovered := -1
var captured := -1
var finger := -1
var pressed_key := 0
var press_owner := PressOwner.NONE
var leaving := false
var notice: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
	for layer in manifest.screens[page].layers:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		if layer.kind == "static":
			sprite.texture = load(DIRECTORY + layer.image)
			sprite.scale = Vector2.ONE / manifest.zoom
			continue
		var symbol := int(layer.symbol)
		var matrix: Array = layer.matrix
		var transform_source := Transform2D(Vector2(matrix[0], matrix[1]), Vector2(matrix[2], matrix[3]), Vector2(matrix[4], matrix[5]))
		var bounds := Rect2(layer.bounds[0], layer.bounds[1], layer.bounds[2], layer.bounds[3])
		sprite.transform = transform_source.translated_local(bounds.position).scaled_local(Vector2.ONE / manifest.zoom)
		sprite.texture = load(DIRECTORY + "%d-0.png" % symbol)
		if layer.kind == "quality":
			continue # The port always renders at full quality.
		var textures: Array[Texture2D] = []
		for frame in int(layer.frames):
			textures.append(load(DIRECTORY + "%d-%d.png" % [symbol, frame]))
		# Expand the original 35.55px backplates to 44px targets without overlap.
		var target := transform_source * bounds
		target = target.grow_individual(0, maxf(0, (44-target.size.y)/2), 0, maxf(0, (44-target.size.y)/2))
		target.position.y = clampf(target.position.y, 0, 400 - target.size.y)
		buttons.append({"sprite": sprite, "textures": textures, "target": target, "action": ACTIONS[symbol]})
	if page != "menu":
		var back := _text("‹ BACK", Rect2(434,376,108,23), 14)
		buttons.append({"label": back, "target": Rect2(434,356,108,44), "action": "back"})
	if page == "help":
		_text("Touch: left stick + Bomb · Release between special shots" if touch_help else "Also: WASD in 1P · Esc pauses · M toggles sound", Rect2(15,357,515,16), 11)
	notice = _text("", Rect2(190,376,239,23), 11)
	_refresh()

func _text(value: String, rectangle: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rectangle.position
	label.size = rectangle.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("75255f"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func set_muted(value: bool) -> void:
	muted = value
	_refresh()

func show_notice(value: String) -> void:
	notice.text = value

func _refresh() -> void:
	for index in buttons.size():
		var button := buttons[index]
		var active := index == hovered
		var down := index == captured
		if button.has("label"):
			button.label.modulate = Color("dc438d") if active or down else Color.WHITE
		elif button.action == "sound":
			button.sprite.texture = button.textures[1 if muted else 0]
		else:
			button.sprite.texture = button.textures[2 if down else 1 if active else 0]

func _hit(point: Vector2) -> int:
	for index in buttons.size():
		if buttons[index].target.has_point(point):
			return index
	return -1

func _activate(index: int) -> void:
	if index < 0 or leaving:
		return
	var action: String = buttons[index].action
	leaving = action not in ["sound", "best", "portal"]
	action_requested.emit(action)

func _cancel_press() -> void:
	press_owner = PressOwner.NONE
	captured = -1
	finger = -1
	pressed_key = 0
	_refresh()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_press()

func _input(event: InputEvent) -> void:
	if leaving or not is_visible_in_tree():
		return
	if event is InputEventKey:
		_key_input(event)
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion:
		hovered = _hit(get_global_transform_with_canvas().affine_inverse() * event.position)
		_refresh()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if press_owner not in [PressOwner.NONE, PressOwner.MOUSE]:
			return
		var hit := _hit(get_global_transform_with_canvas().affine_inverse() * event.position)
		if event.double_click:
			_cancel_press()
			return
		if event.pressed:
			if press_owner == PressOwner.NONE:
				press_owner = PressOwner.MOUSE
				captured = hit
		elif press_owner == PressOwner.MOUSE:
			var chosen := captured if hit == captured else -1
			_cancel_press()
			_activate(chosen)
		_refresh()
	elif event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if press_owner not in [PressOwner.NONE, PressOwner.TOUCH] or (finger != -1 and event.index != finger):
			return
		if event.double_tap:
			_cancel_press()
			return
		if event.canceled:
			if event.index == finger:
				_cancel_press()
			return
		var hit := _hit(get_global_transform_with_canvas().affine_inverse() * event.position)
		if event.pressed and finger == -1:
			press_owner = PressOwner.TOUCH
			finger = event.index
			captured = hit
		elif not event.pressed and event.index == finger:
			var chosen := captured if hit == captured else -1
			_cancel_press()
			_activate(chosen)
		_refresh()

func _key_input(event: InputEventKey) -> void:
	if event.keycode not in [KEY_ENTER, KEY_SPACE, KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESCAPE, KEY_M]:
		return
	get_viewport().set_input_as_handled()
	if event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_SPACE]:
		if event.pressed and press_owner == PressOwner.NONE:
			press_owner = PressOwner.KEYBOARD
			pressed_key = event.keycode
			captured = focus
		elif not event.pressed and press_owner == PressOwner.KEYBOARD and pressed_key == event.keycode:
			var chosen := captured
			_cancel_press()
			_activate(chosen)
	elif event.pressed:
		_cancel_press()
		if event.keycode == KEY_ESCAPE:
			if page != "menu":
				leaving = true
				action_requested.emit("back")
		elif event.keycode == KEY_M:
			action_requested.emit("sound")
		else:
			var step := -1 if event.keycode in [KEY_UP, KEY_LEFT] or (event.keycode == KEY_TAB and event.shift_pressed) else 1
			focus = posmod(focus + step, buttons.size())
			hovered = focus
	_refresh()
