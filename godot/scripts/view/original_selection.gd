class_name OriginalSelection
extends OriginalMenu
## Root frame 8: independent choices, source duplicate exclusion and confirmation.

signal choices_changed(first: int, second: int)

const HERO_ORIGINS := [Vector2(109.25,180.65), Vector2(198.85,180.55), Vector2(290.25,180.65), Vector2(381.45,180.65)]
var players := 1
var choices: Array[int] = [1,2]
var confirmed: Array[bool] = [false,false]
var active_slot := 0
var held_keys: Dictionary = {}
var pointers: Array[Node2D] = []
var pointer_frames: Array = []
var pointer_textures: Dictionary = {}
var age := 0
var blink_due: Array[int] = [2,2]
var blink_started: Array[int] = [-100,-100,-100,-100]
var elapsed := 0.0

func _init() -> void:
	page = "select"

func _ready() -> void:
	super._ready()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
	pointer_frames = manifest.pointer_frames
	for symbol in [200,209]:
		var textures: Array[Texture2D] = []
		for frame in (4 if symbol == 200 else 8):
			textures.append(load(DIRECTORY + "%d-%d.png" % [symbol,frame]))
		pointer_textures[symbol] = textures
	for slot in players:
		var pointer := Node2D.new()
		pointer.scale = Vector2(2,2)
		for symbol in [200,209]:
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			pointer.add_child(sprite)
		add_child(pointer)
		pointers.append(pointer)
	for hero in 4:
		buttons.append({"target": Rect2(HERO_ORIGINS[hero] + Vector2(-10,-55),Vector2(82,100)), "action": "hero%d" % (hero+1)})
	# Direct touch additions use the original confirmation-key artwork as targets.
	# The source itself supports only keyboard selection.
	buttons.append({"target": Rect2(279,311,111,44) if players == 1 else Rect2(207,316,112,44), "action": "confirm0"})
	if players == 2:
		buttons.append({"target": Rect2(392,308,54,44), "action": "confirm1"})
	_text("Tap a robot, then its CONFIRM key" if players == 1 else "Tap for P1, confirm; then tap for P2 and confirm", Rect2(195,357,350,18), 10)
	_refresh_selection()

func _refresh() -> void:
	# Invisible source-art targets have no button sprite to recolor.
	for button in buttons:
		if not button.has("sprite") and not button.has("label"):
			continue
		var index := buttons.find(button)
		if button.has("label"):
			button.label.modulate = Color("dc438d") if index in [hovered,captured] else Color.WHITE
		elif button.action == "sound":
			button.sprite.texture = button.textures[1 if muted else 0]

func _activate(index: int) -> void:
	if index < 0 or leaving:
		return
	var action: String = buttons[index].action
	if action.begins_with("hero"):
		choose(active_slot, int(action.trim_prefix("hero")))
	elif action.begins_with("confirm"):
		confirm(int(action.trim_prefix("confirm")))
	else:
		super._activate(index)

func choose(slot: int, hero: int) -> void:
	if confirmed[slot] or (players == 2 and choices[1-slot] == hero):
		return
	choices[slot] = hero
	blink_due[slot] = age + 2
	choices_changed.emit(choices[0],choices[1])
	_refresh_selection()

func move_choice(slot: int, step: int) -> void:
	if confirmed[slot]:
		return
	var hero := posmod(choices[slot]-1+step,4)+1
	if players == 2 and hero == choices[1-slot]:
		hero = posmod(hero-1+step,4)+1
	choose(slot,hero)

func confirm(slot: int) -> void:
	if confirmed[slot] or leaving:
		return
	confirmed[slot] = true
	active_slot = 1 if players == 2 and not confirmed[1] else 0
	_refresh_selection()
	if confirmed[0] and (players == 1 or confirmed[1]):
		leaving = true
		action_requested.emit("start")

func _cancel_press() -> void:
	held_keys.clear()
	super._cancel_press()

func _key_input(event: InputEventKey) -> void:
	if event.keycode in [KEY_ESCAPE,KEY_M]:
		super._key_input(event)
		return
	var controls := [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_SPACE,KEY_ENTER]
	if players == 2:
		controls.append_array([KEY_A,KEY_W,KEY_D,KEY_S])
	if event.keycode not in controls:
		return
	get_viewport().set_input_as_handled()
	if event.echo or press_owner not in [PressOwner.NONE,PressOwner.KEYBOARD]:
		return
	if event.pressed:
		held_keys[event.keycode] = true
		press_owner = PressOwner.KEYBOARD
		return
	if not held_keys.erase(event.keycode):
		return
	if held_keys.is_empty():
		press_owner = PressOwner.NONE
	var slot := 1 if players == 2 and event.keycode in [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_ENTER] else 0
	if event.keycode in [KEY_SPACE,KEY_ENTER]:
		confirm(slot)
	else:
		move_choice(slot,-1 if event.keycode in [KEY_LEFT,KEY_UP,KEY_A,KEY_W] else 1)

func _process(delta: float) -> void:
	elapsed += delta * 35.0
	while elapsed >= 1.0:
		elapsed -= 1.0
		age += 1
		for slot in players:
			if age >= blink_due[slot]:
				blink_started[choices[slot]-1] = age
				blink_due[slot] = age + 100
	_refresh_selection()

func _refresh_selection() -> void:
	var eye := 0
	for visual in visuals:
		if visual.symbol == 519:
			visual.sprite.texture = visual.textures[players-1]
		elif visual.symbol == 509:
			var frame := age-blink_started[eye]+1
			visual.sprite.texture = visual.textures[frame if frame < 14 else 0]
			eye += 1
	for slot in pointers.size():
		var pointer := pointers[slot]
		pointer.position = HERO_ORIGINS[choices[slot]-1]
		var placements: Array = pointer_frames[0 if confirmed[slot] else age % 60]
		for placement in placements:
			var symbol := int(placement.symbol)
			var sprite: Sprite2D = pointer.get_child(0 if symbol == 200 else 1)
			var m: Array = placement.matrix
			var basis := Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))
			basis.origin += Vector2(placement.bounds[0],placement.bounds[1])
			sprite.transform = basis.scaled_local(Vector2.ONE/2)
			sprite.texture = pointer_textures[symbol][choices[slot]-1 + (slot*4 if symbol == 209 else 0)]
