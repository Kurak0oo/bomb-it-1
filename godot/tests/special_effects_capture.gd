extends SceneTree
## Presentation inputs are shared with the independent original-clip fixture.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(550,400)
	RenderingServer.set_default_clear_color(Color.WHITE)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/special_effect_scenarios.json"))
	var observations := {}
	for scenario: String in profile.scenarios:
		var state := GameState.new()
		var rows := PackedStringArray()
		for y in 13: rows.append("...............")
		state.setup(rows)
		for actor in state.heroes:
			actor.alive = false
			actor.death_ticks = 36
		var actor := state.heroes[0]
		actor.cell = Vector2i(8,6)
		actor.facing = 2 if scenario == "impact" else int(scenario.get_slice("-",1))
		var view := GameView.new()
		view.state = state
		view.frozen = true
		root.add_child(view)
		for child in view.get_children(): child.visible = false
		var weapon := SpecialState.new("rocket" if scenario == "impact" else scenario.get_slice("-",0),actor)
		if weapon.kind in ["ice","fire"]:
			weapon.painted.append(actor.cell)
			weapon.born.append(0)
		if weapon.kind == "grenade": weapon.cell += weapon.direction*2
		state.specials.append(weapon)
		if scenario == "impact":
			state.cell_at(Vector2i(9,6)).kind = GameState.Kind.BRICK
			weapon.just_placed = false
			state.register_callback(weapon)
		var samples := []
		for tick in range(-1,int(profile.scenarios[scenario].end)):
			if scenario == "impact":
				if tick >= 0: state.tick([])
			else:
				weapon.age = tick+1
				state.tick_number = tick+1
			view.sync_view()
			# Static rocket timeline fixtures do not emit motion smoke.
			if scenario != "impact":
				for trail in view._trails: trail.node.visible = false
			var visible: bool
			if weapon.kind in ["fire","ice"]:
				visible = not view._effect_clips.is_empty()
			elif view._special_sprites.has(weapon):
				var group: Node2D = view._special_sprites[weapon]
				visible = group.get_child_count()>0 and group.get_child(0).visible
			samples.append({"tick":tick,"values":[1 if visible else 0,view._trails.size()]})
			if float(tick) in profile.scenarios[scenario].captures:
				await preload("res://tests/qa_capture.gd").capture(self,"%s-frame-%s" % [scenario,"-1" if tick == -1 else "%02d" % tick])
		observations[scenario] = samples
		view.free()
	var file := FileAccess.open(OS.get_environment("BOMB_IT_QA_DIR").path_join("../trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"godot-rebuild","runtime":Engine.get_version_info().string,"fps":35,"scenarios":observations},"  "))
	print("SPECIAL_EFFECT_CAPTURE_OK")
	quit()
