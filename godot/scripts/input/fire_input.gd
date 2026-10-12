class_name FireInput
extends RefCounted

# Preserve display-rate transitions in order at the 35 Hz command boundary.
# Keyboard and touch form one button: releasing either must not release both.
var _sources: Dictionary = {}
var _blocked: Dictionary = {}
var _transitions: Array[bool] = []
var _sampled := false
var _release_pending := false

func set_source(source: String, pressed: bool) -> void:
	if _blocked.has(source):
		if not pressed:
			_blocked.erase(source)
		return
	var before := _sources.values().has(true)
	_sources[source] = pressed
	var after := _sources.values().has(true)
	if before != after:
		_transitions.append(after)

func cancel() -> void:
	for source in _sources:
		if _sources[source]:
			_blocked[source] = true
	_sources.clear()
	_transitions.clear()
	_release_pending = _release_pending or _sampled
	_sampled = false

func poll() -> PlayerCommands:
	var command := PlayerCommands.new()
	if _release_pending:
		_release_pending = false
		command.bomb_released = true
		return command
	if not _transitions.is_empty():
		var next: bool = _transitions.pop_front()
		command.bomb_pressed = next and not _sampled
		command.bomb_released = not next and _sampled
		_sampled = next
	command.bomb_requested = _sampled
	return command
