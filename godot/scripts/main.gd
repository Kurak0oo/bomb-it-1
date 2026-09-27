extends Node2D

const STEP := 1.0 / SimRules.SIMULATION_FPS
const MAX_TICKS_PER_FRAME := 5

var _accumulator := 0.0
var _commands := PlayerCommands.new()
var _board: GameBoard


func _ready() -> void:
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_up", KEY_UP)
	_bind_key("move_right", KEY_RIGHT)
	_bind_key("move_down", KEY_DOWN)
	_bind_key("place_bomb", KEY_SPACE)

	var backdrop := Sprite2D.new()
	backdrop.texture = load("res://art/backdrop.png")
	backdrop.centered = false
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(backdrop)

	_board = GameBoard.new()
	_board.position = SimRules.GAME_ORIGIN
	add_child(_board)


func _process(delta: float) -> void:
	_accumulator += delta
	var ticks := 0
	while _accumulator >= STEP and ticks < MAX_TICKS_PER_FRAME:
		_accumulator -= STEP
		_commands.poll_keyboard()
		_board.tick(_commands)
		ticks += 1
	if ticks == MAX_TICKS_PER_FRAME:
		_accumulator = 0.0
	_board.sync_view()


func _bind_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
