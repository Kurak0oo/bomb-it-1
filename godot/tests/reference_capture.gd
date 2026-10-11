extends SceneTree
## Controlled fixture corresponding to the instrumented original SWF.
## Observations are compared, never used to change simulation rules.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(550,400)
	RenderingServer.set_default_clear_color(Color.WHITE)
	var scenarios := {}
	for scenario in ["death", "explosion", "brick"]:
		var state := GameState.new()
		var rows := PackedStringArray()
		for y in 13:
			rows.append("...............")
		state.setup(rows)
		var actor := state.heroes[0]
		actor.cell = Vector2i(8,6)
		actor.shield = 999
		var hero: HeroView
		if scenario == "death":
			actor.alive = false
			actor.death_position = Vector2(240,210)
			hero = HeroView.new()
			hero.actor = actor
			hero.art = OriginalArt.new()
			hero.frozen = true
			root.add_child(hero)
		else:
			if scenario == "brick":
				state.cell_at(Vector2i(9,6)).kind = GameState.Kind.BRICK
			var command := PlayerCommands.new()
			command.request_bomb()
			state.tick([command])
			state.bombs[0].fuse = 1
			state.tick([])
		var samples := []
		for tick in 40:
			if scenario == "death":
				hero.advance_presentation()
			else:
				state.tick([])
			var dying: bool = scenario == "death" and hero.visible
			samples.append({"tick":tick,
				"deathFrame": hero.death_age + 1 if dying else 0,
				"heroVisible": dying and hero.body.visible,
				"silhouetteVisible": dying and hero.death.layers[1].visible,
				"centerEnergy":state.cell_at(Vector2i(8,6)).energy,
				"armEnergy":state.cell_at(Vector2i(9,6)).energy,
				"brickBlocking":state.cell_at(Vector2i(9,6)).kind != GameState.Kind.FLOOR,
				"blastVisible":not state.explosions.is_empty()})
			if scenario == "death" and tick in [0,4,5,10,11,19,20,34,35]:
				await preload("res://tests/qa_capture.gd").capture(self, "frame-%02d" % tick)
		scenarios[scenario] = samples
		if is_instance_valid(hero):
			hero.free()
	var directory := OS.get_environment("BOMB_IT_QA_DIR")
	if directory == "":
		directory = ProjectSettings.globalize_path("res://../.artifacts/reference/rebuilt/death")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("../trace.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write reference capture")
		quit(1)
		return
	file.store_string(JSON.stringify({"source":"godot-rebuild", "runtime":Engine.get_version_info().string,
		"fps":35, "tick_origin":"first update after fixture creation", "scenarios":scenarios}, "  "))
	print("REFERENCE_CAPTURE_OK")
	quit()
