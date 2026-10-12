extends SceneTree
## Observes command behavior; optional regression compares independent source rows.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://tests/fixtures/order_scenarios.json"
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
		actor.cell = Vector2i(8,6)
		actor.shield = 999
		actor.lives = 3
		actor.bombs_available = 3
		actor.bomb_capacity = 3
		actor.special_weapon = fixture.weapon
		actor.special_count = 0 if fixture.weapon == "bomb" else 3
		for at in fixture.walls:
			state.cell_at(Vector2i(at[0],at[1])).kind = GameState.Kind.SOLID
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
			var specials: Array[String] = []
			for y in 13:
				for x in 15:
					var bomb: BombState = state.cell_at(Vector2i(x,y)).bomb
					if bomb != null:
						bombs += "%d,%d,%d;" % [x,y,bomb.fuse]
			for weapon in state.specials:
				if weapon.kind in ["rocket","mine","grenade","gas","ice","fire"]:
					var direction: Vector2i = Vector2i.ZERO if weapon.kind in ["mine","gas"] else weapon.direction
					specials.append("%s,%d,%d,%d,%d;" % [weapon.kind,weapon.origin.x,weapon.origin.y,direction.x,direction.y])
			specials.sort()
			samples.append({"tick":tick,"cellX":actor.cell.x,"cellY":actor.cell.y,"facing":actor.facing,
				"moving":actor.moving,"moveRemaining":actor.ticks_remaining if actor.moving else 0,
				"prevFire":actor.prev_fire,"fireReady":actor.fire_ready,"bombsAvailable":actor.bombs_available,
				"specialCount":actor.special_count,"bombs":bombs,"specials":"".join(specials)})
		scenarios[fixture.name] = samples
	var capture := {"source":"godot-rebuild","runtime":Engine.get_version_info().string,
		"profile":config.profile,"fps":int(config.fps),"tick_origin":config.tick_origin,
		"configuration_sha256":FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text(),"scenarios":scenarios}
	var output := OS.get_environment("BOMB_IT_CORE_TRACE")
	if output != "":
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			push_error("Cannot write command-order reference capture")
			quit(1)
			return
		file.store_string(JSON.stringify(capture,"  "))
	if OS.get_cmdline_user_args().has("--verify-reference"):
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/order_original.json"))
		if reference.configuration_sha256 != capture.configuration_sha256 or reference.source != "original-swf-bytecode":
			push_error("Incompatible independent command-order reference")
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
