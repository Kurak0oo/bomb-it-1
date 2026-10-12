extends SceneTree
## Public capture fixture; source bytecode provides independent expectations.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(550,400)
	RenderingServer.set_default_clear_color(Color.WHITE)
	var scenarios := {}
	for scenario in ["bomb","flame1","flame2","flame3","flame4","brick","pickups"]:
		var state := GameState.new()
		var rows := PackedStringArray()
		for y in 13:
			rows.append("...............")
		state.setup(rows)
		for actor in state.heroes:
			actor.alive = false
			actor.death_ticks = 36
		var actor := state.heroes[0]
		actor.cell = Vector2i(8,6)
		actor.character_id = int(scenario.trim_prefix("flame")) if scenario.begins_with("flame") else 1
		actor.bomb_level = 3
		actor.shield = 999
		var view := GameView.new()
		view.state = state
		view.frozen = true
		root.add_child(view)
		# Isolate presentation from scenery without replacing any effect artwork.
		for child in view.get_children():
			child.visible = false
		if scenario == "pickups":
			for i in 6:
				state.cell_at(Vector2i(2+i*2,7)).item = ["life","glove","bomb","shield","power","shoe"][i]
		elif scenario == "brick":
			state.pops.append(GameState.Pop.new(Vector2i(8,6)))
		else:
			actor.alive = true
			var command := PlayerCommands.new()
			command.request_bomb()
			state.tick([command])
			if scenario.begins_with("flame"):
				state.bombs[0].fuse = 1
				state.tick([])
		view.sync_view()
		for hero in view._hero_sprites.values():
			hero.visible = false
		var samples := []
		var end := 107 if scenario == "pickups" else 81 if scenario == "bomb" else 22
		for tick in range(-1,end):
			if tick >= 0:
				state.tick([])
				if scenario == "pickups" and tick == 85:
					for i in 6:
						state.cell_at(Vector2i(2+i*2,7)).item = ""
				view.sync_view()
				for hero in view._hero_sprites.values():
					hero.visible = false
			var values := []
			if scenario == "pickups":
				for i in 6:
					var pickup: PickupView = view._item_sprites.get(Vector2i(2+i*2,7))
					if pickup == null and i < view._retiring_items.size():
						pickup = view._retiring_items[i]
					if pickup == null:
						values.append_array([0,0,0])
					else:
						var icon := pickup.layers[1]
						var path := icon.texture.resource_path
						if path.ends_with(".svg"):
							# Read the actual selected source-alpha asset's metadata.
							var variant := int(path.get_base_dir().get_file())
							var frame := int(path.get_file().get_basename())-1
							var meta: Dictionary = view.art.manifest.pickup_removal[str(variant)]
							values.append_array([variant,roundi((icon.position.y-meta.offset[1])*20),roundi(meta.alphas[frame]*256)])
						else:
							values.append_array([int(path.get_file().get_basename()),roundi((icon.position.y - view.art.offset(293).y)*20),roundi(icon.modulate.a*256)])
			elif scenario == "brick":
				values.append(0 if view._pop_sprites.is_empty() or not view._pop_sprites.values()[0].visible else int(view._pop_sprites.values()[0].texture.resource_path.get_file().get_basename()))
			else:
				values.append(0 if view._bomb_sprites.is_empty() else int(view._bomb_sprites.values()[0].texture.resource_path.get_file().get_basename()))
				values.append(0 if view._flame_sprites.is_empty() else roundi(view._flame_sprites.values()[0].modulate.a*256))
				values.append(0 if view._flame_sprites.is_empty() else view._flame_sprites.values()[0].get_child_count())
			samples.append({"tick":tick,"values":values})
			var selected := [-1,0,5,19,39,59,77,78,79,80,84,85,86,94,103,104,105,106] if scenario == "pickups" else [-1,0,19,38,39,40,58,59,60,61,62,71,72,73,74,75,76,77,78,79,80] if scenario == "bomb" else [-1,0,1,2,4,8,9,10,11,12,13,14,15,16,17,18,19,20,21]
			if tick in selected:
				await preload("res://tests/qa_capture.gd").capture(self, "%s-frame-%s" % [scenario,"-1" if tick == -1 else "%02d" % tick])
		scenarios[scenario] = samples
		view.free()
	var file := FileAccess.open(OS.get_environment("BOMB_IT_QA_DIR").path_join("../trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"godot-rebuild","runtime":Engine.get_version_info().string,"fps":35,"scenarios":scenarios},"  "))
	print("EFFECT_CAPTURE_OK")
	quit()
