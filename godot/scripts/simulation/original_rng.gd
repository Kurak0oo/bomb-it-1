class_name OriginalRng
extends RefCounted

# AS2 random(n) call boundary. The Flash runtime PRNG is not recovered.
# Inject recorded integers to compare original random-call order exactly.
var generator := RandomNumberGenerator.new()
var recorded: Array[int] = []
var calls := 0

func _init(value: int = 1) -> void:
	generator.seed = value

func next(limit: int) -> int:
	assert(limit > 0)
	var value: int
	if calls < recorded.size():
		value = recorded[calls]
		assert(value >= 0 and value < limit)
	else:
		value = generator.randi_range(0, limit - 1)
	calls += 1
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
