extends SceneTree
## Observes command behavior; optional regression compares independent source rows.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://tests/fixtures/expiry_scenarios.json"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var scenarios := {}
	for fixture in config.scenarios:
		var state := GameState.new()
		var map := PackedStringArray()
		for y in 13:
			map.append("...............")
		state.setup(map)
		for other in state.heroes:
			other.alive = false
		var actor := state.heroes[0]
		actor.alive = true
		actor.cell = Vector2i(fixture.cell[0],fixture.cell[1])
		actor.shield = 999
		actor.lives = 3
		actor.bombs_available = 3
		actor.bomb_capacity = 3
		var owner := state.heroes[1]
		owner.alive = true
		owner.cell = Vector2i.ZERO
		owner.shield = 99999
		owner.bomb_capacity = 3
		owner.bombs_available = 3
		for spec in fixture.bombs:
			var at := Vector2i(spec.cell[0],spec.cell[1])
			var bomb := BombState.new(at,int(spec.owner)-1)
			bomb.fuse = spec.fuse
			bomb.just_placed = false
			state.bombs.append(bomb)
			state.register_callback(bomb)
			state.cell_at(at).bomb = bomb
			state.heroes[bomb.owner_id].bombs_available -= 1
		if fixture.pulse != null:
			SpecialRules.pulse(state,Vector2i(fixture.pulse[0],fixture.pulse[1]),1)
		if fixture.weapon != null:
			owner.cell = Vector2i(fixture.weapon.cell[0],fixture.weapon.cell[1])
			owner.facing = 2
			owner.special_weapon = fixture.weapon.kind
			owner.special_count = 3
			if not SpecialRules.place(state,owner):
				push_error("Initial special rejected")
				quit(1)
				return
			state.specials.back().just_placed = false
			owner.cell = Vector2i.ZERO
		var was_fire := false
		var samples := []
		for tick in fixture.commands.size():
			var input: Array = fixture.commands[tick]
			var command := PlayerCommands.new()
			command.direction = Vector2i.ZERO if input[0] < 0 else SimRules.direction(input[0])
			command.bomb_requested = input[1]
			command.bomb_released = was_fire and not input[1]
			was_fire = input[1]
			state.tick([command])
			var bombs := ""
			var energies := ""
			for y in 13:
				for x in 15:
					var cell: CellState = state.cell_at(Vector2i(x,y))
					if cell.bomb != null:
						bombs += "%d,%d,%d,%d;" % [x,y,cell.bomb.owner_id+1,cell.bomb.fuse]
					if cell.energy > 0:
						energies += "%d,%d,%d,%d;" % [x,y,cell.energy,cell.energy_owner+1]
			samples.append({"tick":tick,"cellX":actor.cell.x,"cellY":actor.cell.y,
				"moving":actor.moving,"moveRemaining":actor.ticks_remaining if actor.moving else 0,
				"prevFire":actor.prev_fire,"fireReady":actor.fire_ready,"bombsAvailable":actor.bombs_available,
				"owner2Bombs":owner.bombs_available,"bombs":bombs,"energies":energies})
		scenarios[fixture.name] = samples
	var capture := {"source":"godot-rebuild","runtime":Engine.get_version_info().string,
		"profile":config.profile,"fps":int(config.fps),"tick_origin":config.tick_origin,
		"configuration_sha256":FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text(),"scenarios":scenarios}
	var output := OS.get_environment("BOMB_IT_CORE_TRACE")
	if output != "":
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			push_error("Cannot write bomb-expiry reference capture")
			quit(1)
			return
		file.store_string(JSON.stringify(capture,"  "))
	if OS.get_cmdline_user_args().has("--verify-reference"):
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/expiry_original.json"))
		if reference.configuration_sha256 != capture.configuration_sha256 or reference.source != "original-swf-bytecode":
			push_error("Incompatible independent bomb-expiry reference")
			quit(1)
			return
		for name in scenarios:
			for tick in scenarios[name].size():
				for field in scenarios[name][tick]:
					if scenarios[name][tick][field] != reference.scenarios[name][tick][field]:
						print("FAIL: %s tick %d %s: source=%s rebuild=%s" % [name,tick,field,reference.scenarios[name][tick][field],scenarios[name][tick][field]])
						quit(1)
						return
	print("CORE_REFERENCE_CAPTURE_OK")
	quit()
