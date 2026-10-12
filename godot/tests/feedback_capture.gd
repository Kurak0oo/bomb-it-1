extends SceneTree
## Presentation fixture for independent original-symbol comparison.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(550,400)
	RenderingServer.set_default_clear_color(Color.WHITE)
	var scenarios := {}
	var art := OriginalArt.new()
	for scenario in ["pointer", "idle", "walk", "weapons", "depth", "hit"]:
		var container := Node2D.new()
		root.add_child(container)
		var heroes: Array[HeroView] = []
		var state := GameState.new()
		var view: GameView
		if scenario == "hit":
			var rows := PackedStringArray()
			for y in 13:
				rows.append("...............")
			state.setup(rows)
			for actor in state.heroes:
				actor.alive = false
				actor.death_ticks = 36
			var actor := state.heroes[1]
			actor.alive = true
			actor.character_id = 1
			actor.cell = Vector2i(8,7)
			actor.lives = 2
			actor.shield = 0
			view = GameView.new()
			view.state = state
			view.frozen = true
			container.add_child(view)
			state.cell_at(actor.cell).energy = 1
			state.tick([])
			view.sync_view()
		else:
			var count := 6 if scenario in ["weapons", "depth"] else 16 if scenario == "walk" else 8
			for i in count:
				var actor := HeroState.new()
				actor.id = i / 4 if scenario == "pointer" else 0
				actor.character_id = i % 4 + 1
				actor.cell = Vector2i(2 + (i if scenario == "weapons" else i % 4) * 3, 0)
				actor.shield = 0
				actor.facing = i / 4 if scenario == "walk" else 3
				if scenario in ["weapons", "depth"]:
					actor.special_weapon = SpecialRules.WEAPONS[i]
					actor.special_count = i + 1
				if scenario == "depth":
					actor.cell = Vector2i(2+i*2,6)
					var brick := art.sprite(195)
					brick.position += Vector2(actor.cell) * 30
					brick.z_index = OriginalArt.depth(actor.cell)
					container.add_child(brick)
				var hero := HeroView.new()
				hero.actor = actor
				hero.art = art
				hero.frozen = true
				hero.pointer_enabled = scenario == "pointer"
				# Registration is deliberately identical to the source fixture.
				var holder := Node2D.new()
				holder.position.y = 100 + (0 if scenario == "weapons" else i / 4) * 80
				if scenario == "depth":
					holder.position.y = 0
				container.add_child(holder)
				holder.add_child(hero)
				heroes.append(hero)
		var samples := []
		for tick in (151 if scenario == "pointer" else 18):
			if scenario == "hit":
				view.advance_presentation()
			else:
				for hero in heroes:
					if scenario == "walk":
						hero.actor.walk_frame += 1
					hero.sync(tick + 1)
			var pointer_visible: bool = not heroes.is_empty() and heroes[0].player_pointer.visible
			# Observe the actual selected artwork and displayed label registration.
			# Smoke timing is checked by the retained rendered boundary images.
			var body_frame := int(heroes[0].body.texture.resource_path.get_file().get_basename()) if not heroes.is_empty() else 1
			var pointer_y := 0
			if pointer_visible:
				pointer_y = roundi((heroes[0].player_pointer.layers[1].position.y - art.offset(209).y) * 20)
			samples.append({"tick":tick, "bodyFrame":body_frame,
				"pointerVisible":pointer_visible, "pointerLabelTwips":pointer_y,
				"life":state.heroes[1].lives if scenario == "hit" else 0})
			var selected := [0,15,29,45,59,148,149,150] if scenario == "pointer" else [0,2,5,11,14,15,16,17]
			if tick in selected:
				await preload("res://tests/qa_capture.gd").capture(self, "%s-frame-%02d" % [scenario, tick])
		scenarios[scenario] = samples
		container.free()
	var directory := OS.get_environment("BOMB_IT_QA_DIR")
	var file := FileAccess.open(directory.path_join("../trace.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write feedback trace")
		quit(1)
		return
	file.store_string(JSON.stringify({"source":"godot-rebuild", "runtime":Engine.get_version_info().string,
		"fps":35, "tick_origin":"first update after fixture creation", "scenarios":scenarios}, "  "))
	print("FEEDBACK_CAPTURE_OK")
	quit()
