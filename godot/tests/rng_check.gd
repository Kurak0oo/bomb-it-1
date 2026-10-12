extends SceneTree

var failed := false

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		print("FAIL: " + message)

func _init() -> void:
	var rng := OriginalRng.new(72)
	var native := RandomNumberGenerator.new()
	native.seed = 72
	rng.begin_recording()
	for bound in [6,6,5,100,4,2,175]:
		check(rng.next(bound) == native.randi_range(0,bound-1), "recording preserves the seeded backend")
	var tape: Array = rng.recording.duplicate(true)
	check(tape.size() == 7 and tape[0].bound == 6 and tape[6].order == 6, "records bounds and absolute order")
	var replay := OriginalRng.new(99)
	check(replay.begin_replay(tape), "valid recording accepted")
	var seed_state: int = replay.generator.state
	for entry in tape:
		check(replay.next(entry.bound) == entry.result, "strict results replay")
	check(replay.finish_replay(), "every recorded call consumed")
	check(replay.generator.state == seed_state, "strict replay never touches the seeded backend")
	for invalid in [[{"order":0,"bound":4,"result":4}], [{"order":1,"bound":4,"result":1}], [{"order":0,"bound":4,"result":1.5}], [3]]:
		check(not replay.begin_replay(invalid), "invalid result, order or record is rejected before replay")
		check(not replay.finish_replay(), "invalid tape cannot complete")
	var single := [{"order":0,"bound":4,"result":2}]
	replay.begin_replay(single)
	replay.next(5)
	check(not replay.finish_replay() and "bound" in replay.replay_error, "changed requested bound fails closed")
	replay.begin_replay(single)
	replay.next(4)
	replay.next(4)
	check(not replay.finish_replay() and "exhaust" in replay.replay_error, "extra call cannot fall back to seeded randomness")
	replay.begin_replay(single)
	check(not replay.finish_replay() and "unconsumed" in replay.replay_error, "unconsumed records prevent successful completion")
	check(replay.generator.state == seed_state, "all rejected cases leave seeded backend untouched")
	var rounds: Array = []
	var session := GameSession.new()
	var factory := func(seed_value: int) -> OriginalRng:
		var source := OriginalRng.new(seed_value)
		source.begin_recording()
		rounds.append(source)
		return source
	session.start(72,1,1,1,0,factory)
	check(rounds.size() == 1 and rounds[0].recording.size() > 200, "public campaign start exposes generation random boundary")
	if not failed:
		print("RNG_OK")
	quit(1 if failed else 0)
