extends SceneTree
## Observes GameState for shared bomb-motion/grenade fixtures; no expected values.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var push_profile := OS.get_cmdline_user_args().has("--push-profile")
	var grenade_profile := OS.get_cmdline_user_args().has("--grenade-profile")
	var stem := "push" if push_profile else "grenade" if grenade_profile else "motion"
	var path := "res://tests/fixtures/%s_scenarios.json" % stem
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
		actor.lives = 3
		actor.bomb_capacity = 3
		actor.bombs_available = 3
		actor.shield = 999
		for at in fixture.walls:
			state.cell_at(Vector2i(at[0],at[1])).kind = GameState.Kind.SOLID
		for at in fixture.bricks:
			state.cell_at(Vector2i(at[0],at[1])).kind = GameState.Kind.BRICK
		if fixture.bomb != null:
			actor.cell = Vector2i(fixture.bomb[0],fixture.bomb[1])
			var place := PlayerCommands.new()
			place.request_bomb()
			state.tick([place])
			var bomb: BombState = state.bombs[0]
			bomb.fuse = fixture.fuse
			if fixture.prepush:
				# Controlled initial half-step fixture, before either runtime's first update.
				state.cell_at(bomb.cell).bomb = null
				bomb.previous_cell = bomb.cell
				bomb.cell += Vector2i.RIGHT
				state.cell_at(bomb.cell).bomb = bomb
				bomb.slide_direction = Vector2i.RIGHT
				bomb.slide_ticks = 2
		actor.cell = Vector2i(fixture.cell[0],fixture.cell[1])
		actor.facing = fixture.facing
		actor.glove = true
		actor.shield = 999
		actor.special_weapon = fixture.weapon
		actor.special_count = 3 if fixture.weapon == "grenade" else 0
		if fixture.get("initial_grenade",false):
			if SpecialRules.place(state,actor):
				state.specials.back().just_placed = false
		if fixture.energy != null:
			SpecialRules.pulse(state, Vector2i(fixture.energy[0],fixture.energy[1]),0)
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
			var bomb: BombState = null
			var reservation := Vector2i(-1,-1)
			var energies := ""
			var occupancy := ""
			var bricks := ""
			for y in 13:
				for x in 15:
					var cell: CellState = state.cell_at(Vector2i(x,y))
					if cell.energy > 0:
						energies += "%d,%d,%d;" % [x,y,cell.energy]
					if cell.kind != GameState.Kind.FLOOR:
						bricks += "%d,%d;" % [x,y]
					if cell.bomb != null:
						bomb = cell.bomb
						reservation = Vector2i(x,y)
						occupancy += "%d,%d;" % [x,y]
			var grenade: SpecialState = null
			for weapon in state.specials:
				if weapon.kind == "grenade":
					grenade = weapon
			var has_bomb := bomb != null
			var has_grenade := grenade != null
			var logical := Vector2i(-1,-1)
			var pixels := Vector2(-0.05,-0.05)
			if has_bomb:
				logical = bomb.previous_cell if bomb.slide_ticks > 0 else bomb.cell
				# Same public-state interpolation that GameView displays at a fixed update.
				pixels = Vector2(bomb.cell)
				if bomb.slide_ticks > 0:
					pixels = Vector2(bomb.previous_cell).lerp(pixels,1.0-bomb.slide_ticks/2.0)
				pixels *= 30
			samples.append({"tick":tick,"heroCellX":actor.cell.x,"heroCellY":actor.cell.y,"heroMoving":actor.moving,
				"bombActive":has_bomb,"bombCellX":logical.x,"bombCellY":logical.y,
				"reservationX":reservation.x,"reservationY":reservation.y,
				"bombPixelXTwips":roundi(pixels.x*20),"bombPixelYTwips":roundi(pixels.y*20),
				"bombFuse":bomb.fuse if has_bomb else -1,"slideRemaining":bomb.slide_ticks if has_bomb else 0,
				"grenadeActive":has_grenade,"grenadeOriginX":grenade.origin.x if has_grenade else -1,
				"grenadeOriginY":grenade.origin.y if has_grenade else -1,
				"grenadeTargetX":grenade.cell.x if has_grenade else -1,"grenadeTargetY":grenade.cell.y if has_grenade else -1,
				"grenadeFrame":grenade.age+1 if has_grenade else 0,
				"grenadeRootXTwips":roundi(grenade.position.x*20) if has_grenade else -1,
				"grenadeRootYTwips":roundi(grenade.position.y*20) if has_grenade else -1,
				"specialCount":actor.special_count,"fireReady":actor.fire_ready,
				"energies":energies,"occupancy":occupancy,"bricks":bricks})
			if push_profile or grenade_profile:
				samples[-1]["bombsAvailable"] = actor.bombs_available
		scenarios[fixture.name] = samples
	var capture := {"source":"godot-rebuild","runtime":Engine.get_version_info().string,
        "profile":config.profile,"fps":int(config.fps),"tick_origin":config.tick_origin,
        "configuration_sha256":FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text(),"scenarios":scenarios}
	var output := OS.get_environment("BOMB_IT_CORE_TRACE")
	if output != "":
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			push_error("Cannot write motion reference capture")
			quit(1)
			return
		file.store_string(JSON.stringify(capture,"  "))
	if OS.get_cmdline_user_args().has("--verify-reference"):
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s_original.json" % stem))
		if stem == "motion" or reference.configuration_sha256 != capture.configuration_sha256 or reference.source != "original-swf-bytecode":
			push_error("Incompatible independent push reference")
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
