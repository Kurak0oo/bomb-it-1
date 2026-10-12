class_name OriginalRng
extends RefCounted

# AS2 random(n) call boundary. The Flash runtime PRNG is not recovered.
# `recorded` retains the old optional integer prefix for existing fixtures.
# Strict replay validates a complete ordered tape; callers must finish_replay().
# On failure next() returns a placeholder without consuming RNG/state. The error
# remains terminal until a new replay; a failed replay is never a valid result.
var generator := RandomNumberGenerator.new()
var recorded: Array[int] = []
var calls := 0
var recording: Array = []
var replay_error := ""
var _recording := false
var _strict := false
var _tape: Array = []
var _position := 0

func begin_recording() -> void:
	_recording = true
	recording.clear()

func begin_replay(tape: Array) -> bool:
	_strict = true
	_tape = tape.duplicate(true)
	_position = 0
	replay_error = ""
	for index in _tape.size():
		var entry: Variant = _tape[index]
		if not entry is Dictionary:
			return _reject("invalid record at %d" % index)
		for key in ["order","bound","result"]:
			if not entry.has(key) or not (entry[key] is int or entry[key] is float) or not is_finite(float(entry[key])) or float(entry[key]) != floor(float(entry[key])):
				return _reject("invalid %s at %d" % [key,index])
		if entry.order != index or entry.bound <= 0 or entry.result < 0 or entry.result >= entry.bound:
			return _reject("invalid order/bound/result at %d" % index)
	return true

func finish_replay() -> bool:
	if not _strict:
		return _reject("strict replay was not started")
	if replay_error.is_empty() and _position != _tape.size():
		_reject("unconsumed recording at %d of %d" % [_position,_tape.size()])
	return replay_error.is_empty()

func _reject(message: String) -> bool:
	if replay_error.is_empty():
		replay_error = message
	return false

func _init(value: int = 1) -> void:
	generator.seed = value

func next(limit: int) -> int:
	if not replay_error.is_empty():
		return 0
	if limit <= 0:
		_reject("invalid requested bound %d" % limit)
		return 0
	var value: int
	if _strict:
		if _position >= _tape.size():
			_reject("recording exhausted at %d, requested bound %d" % [_position,limit])
			return 0
		if int(_tape[_position].bound) != limit:
			_reject("bound mismatch at %d: expected %d, requested %d" % [_position,int(_tape[_position].bound),limit])
			return 0
		value = int(_tape[_position].result)
		_position += 1
	elif calls < recorded.size():
		value = recorded[calls]
		if value < 0 or value >= limit:
			_reject("invalid legacy recorded result at %d" % calls)
			return 0
	else:
		value = generator.randi_range(0, limit - 1)
	calls += 1
	if _recording:
		recording.append({"order":recording.size(),"bound":limit,"result":value})
	return value

func disorder(values: Array) -> void:
	var last = values.back()
	for i in values.size():
		var j := next(values.size())
		var temporary = values[i]
		values[i] = values[j]
		values[j] = temporary
	if values[0] == last:
		var temporary = values.back()
		values[values.size() - 1] = values[0]
		values[0] = temporary
