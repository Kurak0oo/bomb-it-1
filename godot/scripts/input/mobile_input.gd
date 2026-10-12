class_name MobileInput
extends Control

signal fire_changed(pressed: bool)
signal input_cancelled

var direction := Vector2i.ZERO
var bomb_held := false
var _stick_id := -1
var _bomb_id := -1
var _stick := Vector2.ZERO
var _bomb := Vector2.ZERO
var _offset := Vector2.ZERO
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_cancel()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_cancel())

func _cancel() -> void:
	release_all()
	input_cancelled.emit()

func release_all() -> void:
	_stick_id = -1
	_bomb_id = -1
	direction = Vector2i.ZERO
	_set_bomb(false)
	_offset = Vector2.ZERO
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not enabled:
		return
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index == _stick_id or event.index == _bomb_id:
				_cancel()
			return
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and not event.canceled:
			if _stick_id < 0 and point.distance_to(_stick) < 65:
				_stick_id = event.index
				_move(point)
			elif _bomb_id < 0 and point.distance_to(_bomb) < 42:
				_bomb_id = event.index
				_set_bomb(true)
		else:
			if event.index == _stick_id:
				_stick_id = -1
				direction = Vector2i.ZERO
				_offset = Vector2.ZERO
			if event.index == _bomb_id:
				_bomb_id = -1
				_set_bomb(false)
	elif event is InputEventScreenDrag and event.index == _stick_id:
		_move(get_global_transform_with_canvas().affine_inverse() * event.position)
	queue_redraw()

func _set_bomb(pressed: bool) -> void:
	if bomb_held != pressed:
		bomb_held = pressed
		fire_changed.emit(pressed)

func _move(point: Vector2) -> void:
	_offset = (point - _stick).limit_length(34)
	direction = Vector2i.ZERO
	if _offset.length() > 9:
		if absf(_offset.x) > absf(_offset.y):
			direction = Vector2i.RIGHT if _offset.x > 0 else Vector2i.LEFT
		else:
			direction = Vector2i.DOWN if _offset.y > 0 else Vector2i.UP

func configure(stick: Vector2, bomb: Vector2) -> void:
	if _stick == stick and _bomb == bomb:return
	_cancel()
	_stick = stick
	_bomb = bomb
	queue_redraw()

func _draw() -> void:
	draw_circle(_stick, 48, Color(0.12,0.1,0.25,0.55))
	draw_arc(_stick, 48, 0, TAU, 48, Color(1,1,1,0.7), 2, true)
	draw_circle(_stick + _offset, 21, Color(1,0.35,0.67,0.85))
	draw_circle(_bomb, 36, Color(1,0.2,0.5,0.9) if bomb_held else Color(0.12,0.1,0.25,0.65))
	draw_arc(_bomb, 36, 0, TAU, 48, Color(1,1,1,0.8), 2, true)
	draw_string(ThemeDB.fallback_font, _bomb + Vector2(-22,5), "BOMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
