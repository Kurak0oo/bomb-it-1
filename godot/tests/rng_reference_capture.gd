extends SceneTree

class SessionRng extends OriginalRng:
	var sink: Array
	var context: Dictionary
	func next(bound: int) -> int:
		var value := super.next(bound)
		sink.append({"order":sink.size(),"phase":context.phase,"bound":bound,"result":value,"seed":str(generator.seed)})
		return value

var failed := false

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		print("FAIL: " + message)

func tape(calls: Array, phase: String, category: String) -> Array:
	var result: Array = []
	var generation := phase == "retry" or phase.begins_with("drop-")
	for entry in calls:
		if entry.phase != phase:
			continue
		if entry.site == "f1:22882":
			generation = true
		var group := "generation" if generation else "music" if int(entry.bound) == 4 else "weapons"
		if group == category or category == "all":
			result.append({"order":result.size(),"bound":entry.bound,"result":entry.result})
	return result

func source_for(entries: Array) -> OriginalRng:
	var source := OriginalRng.new(99)
	check(source.begin_replay(entries),source.replay_error)
	return source

func empty_state() -> GameState:
	var state := GameState.new()
	var rows := PackedStringArray()
	for y in 13:
		rows.append("...............")
	state.setup(rows)
	return state

func snapshot(state: GameState, rotation: Array, phase: String, topology: bool) -> Dictionary:
	var stage := 1 if phase in ["initial","retry"] else int(phase.trim_prefix("stage"))
	var data := {"scene":state.scene_style,"floor":state.floor_style,"center":state.center_style,
		"brick_styles":state.brick_styles.duplicate(),"rotation":rotation.duplicate(),"special_index":((stage-1)%3)*2,
		"stage":stage,"shields":[],"cells":[]}
	if not topology:
		for hero in state.heroes:
			data.shields.append(hero.shield)
	for y in 13:
		for x in 15:
			var cell := state.cell_at(Vector2i(x,y))
			var kind := cell.kind
			if topology and kind == GameState.Kind.BRICK:
				kind = GameState.Kind.FLOOR
			var style := cell.style if kind != GameState.Kind.FLOOR else 0
			if x in [6,7] and y in [5,6]:
				style = state.center_style if x == 6 and y == 5 else 0
			data.cells.append([x,y,kind,style])
	return data

func run() -> void:
	var path := OS.get_environment("BOMB_IT_RNG_REFERENCE")
	var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not original is Dictionary or original.get("schema","") != "rng-v1":
		print("FAIL: missing original RNG capture")
		quit(1)
		return
	var report := {"schema":"rng-v1","source":"godot-replay","original_capture_sha256":FileAccess.get_sha256(path),"scenarios":{},"full_session":[]}
	for name in original.scenarios:
		var observed: Dictionary = original.scenarios[name]
		var result := {"snapshots":{},"drops":[],"replay":[],"shuffles":[]}
		var rotation: Array = SpecialRules.WEAPONS.duplicate()
		var state: GameState
		for phase in ["initial","retry","stage2","stage3","stage4"]:
			var weapons := tape(observed.calls,phase,"weapons")
			if not weapons.is_empty():
				var source := source_for(weapons)
				source.disorder(rotation)
				check(source.finish_replay(),"weapon rotation: "+source.replay_error)
			var source := source_for(tape(observed.calls,phase,"generation"))
			var next := empty_state()
			next.rng = source
			if phase == "retry":
				next.scene_style=state.scene_style
				next.floor_style=state.floor_style
				next.center_style=state.center_style
				next.brick_styles=state.brick_styles
				for y in 13:
					for x in 15:
						var at:=Vector2i(x,y)
						if state.cell_at(at).kind == GameState.Kind.SOLID:
							next.cell_at(at).kind=GameState.Kind.SOLID
							next.cell_at(at).style=state.cell_at(at).style
				BoardGenerator.populate(next,source)
			else:
				BoardGenerator.generate(next,source)
			state=next
			var complete := source.finish_replay()
			result.replay.append({"phase":phase,"passed":complete,"calls":source.calls,"error":source.replay_error})
			check(complete,"generation "+name+"/"+phase+": "+source.replay_error)
			if phase != "retry":
				result.snapshots[phase+"/topology"]=snapshot(state,rotation,phase,true)
			result.snapshots[phase+"/population"]=snapshot(state,rotation,phase,false)
			if phase == "initial":
				state.items_enabled=true
				state.special_choices=[rotation[0],rotation[1]]
				for drop in observed.drops:
					var at:=Vector2i(int(drop.cell[0]),int(drop.cell[1]))
					var cell:=state.cell_at(at)
					# Isolate drop semantics from any preceding geometry discrepancy.
					cell.kind=GameState.Kind.BRICK
					cell.item=""
					state.rng=source_for(tape(observed.calls,"drop-%d" % int(drop.case),"all"))
					state._break_brick(cell,at,0)
					check(state.rng.finish_replay(),"drop: "+state.rng.replay_error)
					result.drops.append({"case":drop.case,"cell":drop.cell,"item":cell.item})
		var boundary_source := source_for(tape(observed.calls,"shuffle-boundary","all"))
		var boundary: Array = [1,2,3,4]
		boundary_source.disorder(boundary)
		check(boundary_source.finish_replay(),"boundary shuffle: "+boundary_source.replay_error)
		result.shuffles.append({"case":"boundary","before":[1,2,3,4],"after":boundary})
		var shuffle_source := source_for(tape(observed.calls,"shuffle-random","all"))
		var tracks: Array = [1,2,3,4]
		for index in 100:
			var before := tracks.duplicate()
			shuffle_source.disorder(tracks)
			result.shuffles.append({"case":str(index),"before":before,"after":tracks.duplicate()})
		check(shuffle_source.finish_replay(),"repeated shuffle: "+shuffle_source.replay_error)
		report.scenarios[name]=result
	# Whole normal session policy is recorded separately; do not discard setup/music differences.
	var context := {"phase":"initial"}
	var factory := func(seed_value: int) -> OriginalRng:
		var source := SessionRng.new(seed_value)
		source.sink=report.full_session
		source.context=context
		return source
	var session := GameSession.new()
	session.start(72,1,1,1,0,factory)
	for phase in ["retry","stage2","stage3","stage4"]:
		context.phase=phase
		session.result="lose" if phase=="retry" else "win"
		session.next_round()
	var output:=FileAccess.open(OS.get_environment("BOMB_IT_RNG_REBUILT"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report))
	output.close()
	if not failed:
		print("RNG_REFERENCE_CAPTURE_OK")
	quit(1 if failed else 0)
